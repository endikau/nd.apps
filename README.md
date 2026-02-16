# nd.apps Shiny Serve

Lightweight instructions for building and running the Shiny serve image.

## Prerequisites
- Docker with BuildKit/buildx enabled (`docker buildx inspect` should succeed).
- `.npmrc` with registry auth. By default the scripts look for it at repo root; override with `NPMRC_PATH=/path/to/.npmrc`.

## Build locally (tracked files only)
Uses a streamed git context so only tracked files are sent to Docker; `.dockerignore` is ignored in this flow.

```bash
./scripts/build_local.sh
```

Result: `nd_apps-shiny_serve:local`.

## Run locally
```bash
docker run --rm -p 12347:3838 nd_apps-shiny_serve:local
```

## CI build (GitHub Actions)
`.github/workflows/build.yml` builds from `git ls-files | tar | docker buildx build` and pushes `ghcr.io/<owner>/nd_apps-shiny_serve:latest`. It expects the secret `NPMRC_FILE` containing your `.npmrc` contents.

## Notes
- `.dockerignore` is intentionally `**` (ignore all) to prevent accidental `docker build .`; the supported path is the streamed git context used by the script and CI.
- The Dockerfile copies the tracked repo into `/srv/shiny-server/apps`, runs `npm update`, then `scripts/setup_envs.R`.
