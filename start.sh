#!/bin/bash
# Start script for the Funkwhale Railway template.
# Runs migrations, creates the first admin, then starts gunicorn, Celery
# worker, Celery beat and nginx in one container.
set -euo pipefail

log() { echo "[funkwhale-railway] $*"; }

: "${DJANGO_SECRET_KEY:?DJANGO_SECRET_KEY must be set}"
: "${DATABASE_URL:?DATABASE_URL must be set (Postgres)}"
: "${CACHE_URL:?CACHE_URL must be set (Redis)}"

# Public address: Railway's domain unless FUNKWHALE_HOSTNAME is set
export FUNKWHALE_HOSTNAME="${FUNKWHALE_HOSTNAME:-${RAILWAY_PUBLIC_DOMAIN:-localhost}}"
export FUNKWHALE_PROTOCOL="${FUNKWHALE_PROTOCOL:-https}"
export DJANGO_SETTINGS_MODULE=config.settings.production
# Railway's health check calls the app as healthcheck.railway.app
export DJANGO_ALLOWED_HOSTS="${DJANGO_ALLOWED_HOSTS:-healthcheck.railway.app,localhost,127.0.0.1}"

# Storage: everything that must survive a redeploy lives on the volume
DATA_DIR="${FUNKWHALE_DATA_DIR:-/srv/funkwhale/data}"
export MEDIA_ROOT="${MEDIA_ROOT:-$DATA_DIR/media}"
export MUSIC_DIRECTORY_PATH="${MUSIC_DIRECTORY_PATH:-$DATA_DIR/music}"
export MUSIC_DIRECTORY_SERVE_PATH="$MUSIC_DIRECTORY_PATH"
export STATIC_ROOT=/app/staticfiles
export FUNKWHALE_SPA_HTML_ROOT=/frontend/
export REVERSE_PROXY_TYPE=nginx

export LOGLEVEL="${LOGLEVEL:-info}"
export FUNKWHALE_WEB_WORKERS="${FUNKWHALE_WEB_WORKERS:-2}"
export CELERYD_CONCURRENCY="${CELERYD_CONCURRENCY:-2}"
export NGINX_MAX_BODY_SIZE="${NGINX_MAX_BODY_SIZE:-512M}"
export C_FORCE_ROOT=true
PORT="${PORT:-8080}"

mkdir -p "$MEDIA_ROOT" "$MUSIC_DIRECTORY_PATH"

log "Funkwhale for $FUNKWHALE_PROTOCOL://$FUNKWHALE_HOSTNAME"
log "Running database migrations"
funkwhale-manage migrate --noinput

# First admin, created once from FUNKWHALE_ADMIN_USERNAME / FUNKWHALE_ADMIN_PASSWORD
ADMIN_USER="${FUNKWHALE_ADMIN_USERNAME:-}"
if [ -n "$ADMIN_USER" ] && [ -n "${FUNKWHALE_ADMIN_PASSWORD:-}" ]; then
  if FW_ADMIN_USER="$ADMIN_USER" funkwhale-manage shell -c \
      "import os,sys; from funkwhale_api.users.models import User; sys.exit(0 if User.objects.filter(username__iexact=os.environ['FW_ADMIN_USER']).exists() else 3)" ; then
    log "Admin user '$ADMIN_USER' already exists"
  else
    log "Creating admin user '$ADMIN_USER'"
    FUNKWHALE_CLI_USER_PASSWORD="$FUNKWHALE_ADMIN_PASSWORD" funkwhale-manage fw users create \
      --username "$ADMIN_USER" \
      --email "${FUNKWHALE_ADMIN_EMAIL:-$ADMIN_USER@${FUNKWHALE_HOSTNAME%%:*}}" \
      --superuser --staff \
      --permission library --permission moderation --permission settings
  fi
fi

sed -e "s#__PORT__#$PORT#g" \
    -e "s#__MEDIA_ROOT__#$MEDIA_ROOT#g" \
    -e "s#__MUSIC_ROOT__#$MUSIC_DIRECTORY_PATH#g" \
    -e "s#__MAX_BODY__#$NGINX_MAX_BODY_SIZE#g" \
    -e "s#__PUBLIC_URL__#$FUNKWHALE_PROTOCOL://$FUNKWHALE_HOSTNAME#g" \
    /etc/funkwhale/nginx.conf.template > /etc/funkwhale/nginx.conf

pids=()
gunicorn config.asgi:application \
  --workers "$FUNKWHALE_WEB_WORKERS" \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 127.0.0.1:5000 --timeout 120 ${GUNICORN_ARGS:-} &
pids+=($!)
celery --app=funkwhale_api.taskapp worker --loglevel=INFO --concurrency="$CELERYD_CONCURRENCY" &
pids+=($!)
celery --app=funkwhale_api.taskapp beat --loglevel=INFO --schedule=/tmp/celerybeat-schedule --pidfile= &
pids+=($!)
nginx -c /etc/funkwhale/nginx.conf -g 'daemon off;' &
pids+=($!)

stop() {
  log "Stopping"
  kill -TERM "${pids[@]}" 2>/dev/null || true
  wait || true
  exit 0
}
trap stop TERM INT

# If any process exits, stop the others so Railway restarts the container
set +e
wait -n
code=$?
log "A process exited (code $code), stopping the container"
kill -TERM "${pids[@]}" 2>/dev/null
wait
exit 1
