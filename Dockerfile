# Funkwhale on Railway: one service that runs the web app (nginx + gunicorn),
# the Celery worker and Celery beat. Railway volumes can't be shared between
# services, and all of these need the same media and music folders.
FROM funkwhale/front:2.0.14@sha256:0bbf4fa2007e2d3b20fa4f7527e16e8cc84a185faa56e376b63968bedf368e49 AS front

FROM funkwhale/api:2.0.14@sha256:f7945bf050477bed3490c2bc4f2876a12fe61e8fa9298aff20263a0fb3bbb6df

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
