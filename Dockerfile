## Build Arguments ##
#####################
## Set the python image tag to use as the base image. 
# See https://hub.docker.com/_/python?tab=tags for a list of valid tags.
# Set  default below to desired Python version.
ARG PYTHON_TAG=3.9-alpine
##

## Set the UID/GID that sopel will run and make files/folders as.
# For security, these values are set past the upper limit of named users in most
# linux environments. `chown` any volume mounts to the IDs specified here, or 
# change to match your GID (and UID if desired) if you think its okay ¯\_(ツ)_/¯

# for OKD/OpenShift, support arbitrary user ID's:
# https://docs.openshift.com/container-platform/latest/openshift_images/create-images.html
ARG SOPEL_UID=100000
##

## Set the repository used to pull the sopel source
# Set Docker build-arg SOPEL_REPO with private fork, or change default below 
# as desired. Any valid Git URL is acceptable.
ARG SOPEL_REPO=https://github.com/sopel-irc/sopel.git
##

## Set the specific branch/commit for the source
# This can be a branch name, release/tag, or even specific commit hash.
# Set Docker build-arg SOPEL_BRANCH, or replace the default value below.
ARG SOPEL_BRANCH=v7.1.9
##

## Do not modify below this !! ##
#################################

#####
### STAGE 1: Pull latest source
#####
FROM alpine:latest AS git-fetch

ARG SOPEL_REPO
ARG SOPEL_BRANCH

RUN set -ex \
  && apk add --no-cache --virtual .git \
    git \
  && git clone \
    --depth 1 --branch ${SOPEL_BRANCH} \
    ${SOPEL_REPO} /sopel-src \
  && apk del \
    .git
#####
#####

#####
### STAGE 2: Install Sopel
#####
FROM python:${PYTHON_TAG}
# Pre-set ARGs
ARG SOPEL_BRANCH
# Injected ARGs
ARG BUILD_DATE
ARG VCS_REF
ARG DOCKERFILE_VCS_REF
LABEL maintainer="Humorous Baby <humorbaby@humorbaby.net>" \
      org.label-schema.build-date="${BUILD_DATE}" \
      org.label-schema.name="sopel" \
      org.label-schema.description=" \
        Sopel, the Python IRC bot. \
        For stand-alone or compose/stack service use." \
      org.label-schema.url="https://sopel.chat" \
      org.label-schema.vcs-url="https://github.com/sopel-irc/sopel" \
      org.label-schema.vcs-ref="${VCS_REF}" \
      org.label-schema.version="Python ${PYTHON_VERSION}/Sopel ${SOPEL_BRANCH}" \
      org.label-schema.schema-version="1.0" \
      dockerfile.vcs-url="https://github.com/sopel-irc/docker-sopel" \
      dockerfile.vcf-ref="${DOCKERFILE_VCS_REF}"

ARG SOPEL_UID

ENV SOPEL_CONFIG_DIR=/home/sopel/.sopel
RUN set -ex \
  && apk add --no-cache \
    shadow \
  && apk add --no-cache --virtual .build-deps \
    gcc \
    build-base \
\
  && adduser -u ${SOPEL_UID} -G root -h /home/sopel -s /bin/ash sopel -D \
\
  && mkdir $SOPEL_CONFIG_DIR \
  && chown sopel:root /home/sopel/ \
  && chmod -R g=u /home/sopel/

WORKDIR /home/sopel

COPY --from=git-fetch --chown=sopel:root /sopel-src /home/sopel/sopel-src
RUN set -ex \
  && cd ./sopel-src \
  && python -m pip install . \
  && cd .. \
  && rm -rf ./sopel-src \
  && apk del .build-deps

VOLUME [ "/home/sopel/.sopel" ]

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "sopel" ]
