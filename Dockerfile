# syntax=docker/dockerfile:1.6
FROM ghcr.io/endikau/nd_docker-shiny_serve:latest

WORKDIR /srv/shiny-server/apps

# Copy only tracked repo contents (build context supplied via git ls-files).
COPY . /srv/shiny-server/apps/

# Use BuildKit secret mount so npm auth is not baked into layers.
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm update

# Build Python/R envs as the runtime user so reticulate installs under a
# readable HOME (avoids /root-owned interpreters that shiny can't execute).
RUN chown -R shiny:shiny /srv/shiny-server/apps

USER shiny
ENV HOME="/home/shiny"
ENV R_LIBS_USER="$HOME/R/library"
# ENV R_PROFILE_USER=/srv/shiny-server/apps/.Rprofile
ENV PYENV_ROOT="$HOME/.pyenv"

RUN mkdir -p "$R_LIBS_USER"

RUN curl -fsSL https://pyenv.run | bash \
#   && { [ -e '~/.bashrc' ] || touch '~/.bashrc'; } \
  && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc \
  && echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc \
  && echo 'eval "$(pyenv init - bash)"' >> ~/.bashrc \
#   && { [ -e '~/.profile' ] || touch '~/.profile'; } \
  && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile \
  && echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile \
  && echo 'eval "$(pyenv init - bash)"' >> ~/.profile

RUN Rscript --vanilla scripts/setup_envs.R

USER root