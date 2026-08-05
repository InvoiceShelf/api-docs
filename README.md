# InvoiceShelf API Docs

The static [Swagger UI](https://github.com/swagger-api/swagger-ui) site served at
**[api-docs.invoiceshelf.com](https://api-docs.invoiceshelf.com)** — the public REST
API reference for the InvoiceShelf **v3** API.

It is a self-contained static site: a pinned `swagger-ui-dist` plus a committed
`openapi.json`, served by nginx. The committed spec provides a working checked-out site and
a fallback if a refresh cannot be fetched. Before every image build, the build workflow
refreshes it from the app repo ([InvoiceShelf/InvoiceShelf](https://github.com/InvoiceShelf/InvoiceShelf),
`3.x` branch). The app generates that spec with [Scramble](https://scramble.dedoc.co/) —
no annotations, inferred from the app's Form Requests and API Resources.

## How it fits together

```
InvoiceShelf (3.x branch)
  └─ release published  ──▶  .github/workflows/openapi.yml
                               php artisan scramble:export → public/openapi.json (committed)
                               └─ repository_dispatch: spec-updated ─┐
                                                                     ▼
this repo  ──▶  .github/workflows/build.yml
                 scripts/fetch-specs.sh   (pulls 3.x public/openapi.json)
                 docker build             (swagger-ui-dist + openapi.json + nginx)
                 push ghcr.io/invoiceshelf/api-docs:latest
                 └─ repository_dispatch: image-pushed ─┐
                                                        ▼
k8s-production-cluster  ──▶  update-images.yaml bumps the digest in
                              applications/invoiceshelf/api-docs-deployment.yaml
                              └─ ArgoCD syncs → api-docs.invoiceshelf.com
```

## Files

| File | Purpose |
|---|---|
| `index.html` | Swagger UI shell, loads `openapi.json` |
| `openapi.json` | Last committed generated v3 spec; refreshed in the build workspace by `fetch-specs.sh` before the image is built |
| `Dockerfile` | Pinned `swagger-ui-dist` + spec → nginx |
| `default.conf` | nginx config (gzip, cache headers) |
| `scripts/fetch-specs.sh` | Pulls the latest `openapi.json` from the app repo's `3.x` branch |
| `.github/workflows/build.yml` | Build + push image, notify the cluster |

## Local preview

```bash
bash scripts/fetch-specs.sh                 # refresh the working-tree spec (optional)
docker build -t api-docs .
docker run --rm -p 8080:80 api-docs         # open http://localhost:8080
```

## Required CI secret

- `CLUSTER_DISPATCH_PAT` — a PAT with `repo` scope on `ideologix/k8s-production-cluster`,
  used to trigger the cluster's digest bump. If unset, the build still publishes the
  image; the cluster will pick it up on its 6-hourly fallback schedule.

## Adding the v2 API later

The site is intentionally v3-only. To also document the v2 (`2.x`) API, Swagger UI's
`urls` option renders a version dropdown — fetch both specs, name them `openapi-v3.json`
/ `openapi-v2.json`, and switch `index.html` from `url:` to `urls: [...]`.
