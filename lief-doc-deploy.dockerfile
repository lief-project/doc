# Docker file used to deploy LIEF documentation
# docker build -t liefproject/doc-deploy:latest -f ./lief-doc-deploy.dockerfile .
# docker run --name lief-doc liefproject/doc-deploy:latest

FROM debian:buster-slim AS base

LABEL maintainer="Romain Thomas <me@romainthomas.fr>"

# install dependencies
# See: https://github.com/debuerreotype/docker-debian-artifacts/issues/24#issuecomment-360870939
RUN mkdir -p /usr/share/man/man1 && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      locales \
      python3 python3-pip \
      git \
      openssl \
      ssh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# configure locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

