# AGENTS GUIDE — nd.apps Shiny Serve

For LLM/automation agents working in this repo.

## Build & run
- **Local build** (tracked files only): `./scripts/build_local.sh` — requires Docker BuildKit/buildx and an `.npmrc` (override path with `NPMRC_PATH`).
- **Run**: `docker run --rm -p 12347:3838 nd_apps-shiny_serve:local`.
- **CI**: `.github/workflows/build.yml` streams `git ls-files | tar | docker buildx build --push`; needs secret `NPMRC_FILE` containing the `.npmrc` content.

## Dockerfile expectations
- `shiny_serve.Dockerfile` copies the tracked repo into `/srv/shiny-server/apps`, runs `npm update` using a secret-mounted `.npmrc`, then runs `scripts/setup_envs.R`.
- Build context must be the streamed git tar; **do not use** `docker build .` (context is intentionally empty because `.dockerignore` is `**`).

## Secrets & safety
- Never bake `.npmrc` into images; use BuildKit `--secret id=npmrc`.
- Keep `.dockerignore` as `**` unless the build path changes.
- Do not reintroduce `shiny_serve-sc.Dockerfile` unless requested.

## Key files
- `shiny_serve.Dockerfile` — main image.
- `scripts/build_local.sh` — tracked-files BuildKit build.
- `scripts/setup_envs.R` — env/bootstrap.
- `compose.yml` — local run settings (port 12347 -> 3838).

## Quick checklist for changes
1) Use `git ls-files`-based contexts; avoid `docker build .`.
2) Preserve BuildKit secret mounts for npm.
3) Validate `.npmrc` path handling if touching scripts/workflow.
4) Document new steps in `README.md` if the build flow changes.
