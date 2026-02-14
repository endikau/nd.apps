FROM ghcr.io/endikau/nd_docker-shiny_serve:latest

COPY scripts/setup_envs.R /nd_docker_scripts/setup_envs.R
COPY renv.lock /srv/shiny-server/apps/renv.lock
COPY requirements.txt /srv/shiny-server/apps/requirements.txt
WORKDIR /srv/shiny-server/apps
RUN Rscript --vanilla /nd_docker_scripts/setup_envs.R
