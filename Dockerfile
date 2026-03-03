# syntax=docker/dockerfile:1.6
FROM ghcr.io/endikau/nd_docker-shiny_serve:latest

WORKDIR /srv/shiny-server/apps

# Copy only tracked repo contents (build context supplied via git ls-files).
COPY . /srv/shiny-server/apps/

# Use BuildKit secret mount so npm auth is not baked into layers.
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm update

# Build Python/R envs as the runtime user so reticulate installs under a
# readable HOME (avoids /root-owned interpreters that shiny can't execute).
RUN chown -R shiny:shiny /srv/shiny-server/apps /home/shiny \
  && mkdir -p /home/shiny/R/library
ENV HOME=/home/shiny
ENV R_LIBS_USER=/home/shiny/R/library
USER shiny
RUN Rscript --vanilla scripts/setup_envs.R
