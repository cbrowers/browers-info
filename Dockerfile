# syntax=docker/dockerfile:1
# ── Build ────────────────────────────────────────────────────────────────
# Hugo version must stay within Blowfish's supported range (see theme release notes).
FROM ghcr.io/gohugoio/hugo:v0.167.0 AS build
COPY --chown=hugo:hugo . /project
RUN hugo --gc --minify --environment production

# ── Serve ────────────────────────────────────────────────────────────────
FROM nginxinc/nginx-unprivileged:1.30-alpine
LABEL org.opencontainers.image.source="https://github.com/cbrowers/browers-info" \
      org.opencontainers.image.description="www.browers.info static blog"
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /project/public /usr/share/nginx/html
EXPOSE 8080
