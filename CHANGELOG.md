# Changelog

## 2.0.14-1 (2026-11-16)

- README: Deploy on Railway button for the published template (`funkwhale-1`). No change to the image or the start script.

## 2.0.14 (2026-11-16)

- First release of the Railway template: Funkwhale 2.0.14 (`funkwhale/api` and `funkwhale/front`, pinned by digest), Railway Postgres and Redis, one volume at `/srv/funkwhale/data`.
- nginx, gunicorn, Celery worker and Celery beat run in one service, because they share the media volume.
- The first admin is created from `FUNKWHALE_ADMIN_USERNAME` / `FUNKWHALE_ADMIN_PASSWORD`; sign-ups stay closed.
