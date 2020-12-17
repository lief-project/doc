# Docker file used to build LIEF documentation
# docker build -t liefproject/doc:latest -f ./lief-doc.dockerfile .
#
# mkdir -p build && cp generate_doc.sh build/ && chmod 777 build/generate_doc.sh
# docker run -e LIEF_VERSION=0.11.0 -v $(pwd)/build:/src liefproject/doc:latest sh /src/generate_doc.sh

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
      doxygen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip \
  --no-cache-dir \
  install \
    sphinx==3.3.1       \
    breathe==4.24.1     \
    Pygments==2.7.3     \
    sphinx_rtd_theme==0.5.0

# configure locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

