# syntax=docker/dockerfile:1

# ── Stage 1: assemble the static site ────────────────────────────────────────
# Pull a pinned swagger-ui-dist so the rendered docs are reproducible, then drop
# in our shell (index.html) and the two OpenAPI specs.
FROM node:20-alpine AS build
WORKDIR /site

ARG SWAGGER_UI_VERSION=5.21.0
RUN npm pack swagger-ui-dist@${SWAGGER_UI_VERSION} \
  && tar -xzf swagger-ui-dist-*.tgz \
  && cp package/swagger-ui.css \
        package/swagger-ui-bundle.js \
        package/favicon-32x32.png \
        package/favicon-16x16.png \
        ./ \
  && rm -rf package swagger-ui-dist-*.tgz

# Our shell + the spec. CI overwrites the spec with a freshly generated one
# (scripts/fetch-specs.sh) before the build; the committed placeholder only keeps
# the first build green before any real spec has been published.
COPY index.html ./
COPY openapi.json ./

# ── Stage 2: serve with nginx ─────────────────────────────────────────────────
FROM nginx:alpine
COPY default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /site/ /usr/share/nginx/html/
EXPOSE 80
