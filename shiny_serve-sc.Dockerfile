FROM ghcr.io/endikau/nd_apps-shiny_serve:latest

# Embed Shiny app sources so the container runs without a bind mount.
COPY apps/ /srv/shiny-server/apps/
