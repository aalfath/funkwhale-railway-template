# Funkwhale on Railway: one service that runs the web app (nginx + gunicorn),
# the Celery worker and Celery beat. Railway volumes can't be shared between
# services, and all of these need the same media and music folders.
FROM funkwhale/front:2.0.15@sha256:474da38ea297acd0386c280d46a4a82f41f47d400c4092bd4090ad7cca42a1b8 AS front

FROM funkwhale/api:2.0.15@sha256:1993887868f00c4833d50232156ce9c1660c839cd419aba23b90839ae93f4518

RUN apk add --no-cache nginx

# Web app built by the Funkwhale team (same version as the API)
COPY --from=front /usr/share/nginx/html /frontend

COPY nginx.conf /etc/funkwhale/nginx.conf.template
COPY start.sh /usr/local/bin/funkwhale-railway-start

# Collect Django's static files at build time, so the first boot is faster
RUN chmod +x /usr/local/bin/funkwhale-railway-start \
 && DJANGO_SETTINGS_MODULE=config.settings.production \
    DJANGO_SECRET_KEY=build-only FUNKWHALE_HOSTNAME=build.invalid \
    STATIC_ROOT=/app/staticfiles \
    funkwhale-manage collectstatic --noinput > /dev/null

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/funkwhale-railway-start"]
