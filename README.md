[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/funkwhale-1?utm_medium=integration&utm_source=button&utm_campaign=funkwhale)

# Funkwhale on Railway

One-click [Funkwhale](https://www.funkwhale.audio/) for [Railway](https://railway.com): a self-hosted, federated music and podcast server. Upload your music, organise it in libraries and playlists, listen in the browser or in Subsonic apps, and follow other pods over ActivityPub.

**Version:** Funkwhale 2.0.14, from the official images `funkwhale/api` and `funkwhale/front`, pinned by digest in the [`Dockerfile`](Dockerfile).

## What the template deploys

| Service | Source | Purpose |
|---|---|---|
| **Funkwhale** | this repo (`Dockerfile`) | nginx (web app, media) + gunicorn (API) + Celery worker + Celery beat, one container |
| **Postgres** | Railway Postgres | database |
| **Redis** | Railway Redis | cache and Celery broker |

The API, the worker and nginx all need the same media and music folders, and Railway volumes can't be shared between services, so they run together in one service with one volume at `/srv/funkwhale/data` (uploads in `media/`, in-place imports in `music/`).

On every start, `start.sh` runs the database migrations, creates the first admin once, then starts the four processes. If any of them stops, the container exits and Railway restarts it.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `FUNKWHALE_ADMIN_USERNAME` | `podadmin` | First admin, created on the first boot. (`admin`, `root`, `owner` and similar names are reserved by Funkwhale.) |
| `FUNKWHALE_ADMIN_PASSWORD` | `${{secret(24)}}` | Generated. Read it in the service's **Variables** tab. Changing it later does not change the password: use the web app for that. |
| `DJANGO_SECRET_KEY` | `${{secret(64)}}` | Generated. Keep it stable. |
| `FUNKWHALE_HOSTNAME` | `${{RAILWAY_PUBLIC_DOMAIN}}` | The pod's public hostname. Set it **before** you start using the pod: federation IDs contain it and can't change later. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | |
| `CACHE_URL` | `${{Redis.REDIS_URL}}/0` | Also used as the Celery broker. |
| `PORT` | `8080` | nginx listens here. |

Optional settings (add them to the Funkwhale service): `EMAIL_CONFIG` and `DEFAULT_FROM_EMAIL` for e-mail, `CELERYD_CONCURRENCY` (default 2) and `FUNKWHALE_WEB_WORKERS` (default 2) to trade memory for throughput, `NGINX_MAX_BODY_SIZE` (default `512M`) for larger uploads, and the `AWS_*` variables to keep media in S3. See [Funkwhale's configuration reference](https://docs.funkwhale.audio/administrator/configuration/env-file.html).

Sign-ups are closed by default. Open them under **Administration → Settings → Users** if you want other people to register.

## Updates

Railway notifies everyone who deployed this template when a change is merged to `main` here. Each version bump is listed in [`CHANGELOG.md`](CHANGELOG.md), with breaking changes first. Funkwhale runs its own database migrations on start. Back up the Postgres database and the volume before a major upgrade.

## Local test

```sh
docker build -t funkwhale-railway .
docker run -p 8080:8080 \
  -e DJANGO_SECRET_KEY=change-me -e FUNKWHALE_HOSTNAME=localhost:8080 -e FUNKWHALE_PROTOCOL=http \
  -e DATABASE_URL=postgres://... -e CACHE_URL=redis://... \
  -e FUNKWHALE_ADMIN_USERNAME=podadmin -e FUNKWHALE_ADMIN_PASSWORD=change-me \
  -v funkwhale-data:/srv/funkwhale/data funkwhale-railway
```

Funkwhale is licensed under AGPL-3.0 by the Funkwhale collective. This repo only contains the Railway wrapper.
