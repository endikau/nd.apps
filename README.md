# nd.apps Shiny Server

The application image uses the shared `nd_docker-runtime` and
`nd_docker-shiny_serve` images. R, pyenv/Python, Node/npm, `libnode-dev`, s6,
and common system libraries come from the shared runtime.

## Prerequisites
- Docker with BuildKit/buildx enabled (`docker buildx inspect` should succeed).
- `.npmrc` with registry auth. By default the scripts look for it at repo root; override with `NPMRC_PATH=/path/to/.npmrc`.
- Set `GITHUB_PAT` when `renv.lock` references private GitHub repositories.

## Build locally (tracked files only)
Uses a streamed git context so only tracked files are sent to Docker; `.dockerignore` is ignored in this flow.

```bash
./scripts/build_local.sh
```

Result: `nd_apps-shiny_serve:local`.

## Set up local R/Python environments
For non-Docker development, run:

```bash
Rscript scripts/setup_envs.R
```

This restores R packages with renv, creates the Python virtualenv recorded in
`renv.lock`, and installs `requirements.txt`.

## Run locally
```bash
docker run --rm -p 12347:3838 nd_apps-shiny_serve:local
```

or:

```bash
docker compose up
```

`compose.yml` defaults to the local image. To run a published image instead:

```bash
ND_APPS_IMAGE=ghcr.io/endikau/nd_apps-shiny_serve:latest docker compose up
```

## CI build (GitHub Actions)
`.github/workflows/build.yml` builds from the tracked Git state and pushes both
`latest` and an immutable `sha-<commit>` tag. It expects `NPMRC_FILE` and can
optionally use `ND_ACTIONS_READ_TOKEN` for private R dependencies.

## Notes
- `.dockerignore` is intentionally `**` (ignore all) to prevent accidental `docker build .`; the supported path is the streamed git context used by the script and CI.
- R, Python, and npm dependencies are restored in independent stages, so one
  lockfile changing does not invalidate the other dependency caches.
- `@endikau/nd_assets` is installed from the private npm registry with
  `npm ci`.
- The R package `nd.util` is restored from GitHub through `renv.lock`.
- Runtime R package lookup uses the renv-restored library through
  `R_LIBS_SITE=/opt/nd/R/library`; Shiny apps do not depend on runtime
  `.Rprofile` activation.
- The runtime base is pinned through `RUNTIME_TAG`.
