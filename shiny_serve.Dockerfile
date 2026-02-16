# syntax=docker/dockerfile:1.6
FROM ghcr.io/endikau/nd_docker-shiny_serve:latest

WORKDIR /srv/shiny-server/apps

# Copy only tracked repo contents (build context supplied via git ls-files).
COPY . /srv/shiny-server/apps/

# Use BuildKit secret mount so npm auth is not baked into layers.
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm update

RUN Rscript --vanilla scripts/setup_envs.R
