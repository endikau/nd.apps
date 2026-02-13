FROM ghcr.io/endikau/nd_docker-static_render:latest

COPY scripts/setup_envs.R /nd_docker_scripts/setup_envs.R
COPY renv.lock /project/renv.lock
COPY environment.yml /project/environment.yml
WORKDIR /project
RUN Rscript --vanilla /nd_docker_scripts/setup_envs.R

CMD ["quarto", "render"]
