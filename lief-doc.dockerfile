# Docker file used to build LIEF documentation
# docker build --target base -t liefproject/doc:base -f ./lief-doc.dockerfile .
# docker build --target sphinx_lief_theme -t liefproject/doc:sphinx_lief_theme -f ./lief-doc.dockerfile .
#
# mkdir -p build && cp generate_doc.sh build/ && chmod 777 build/generate_doc.sh
#
# Build doc WITHOUT LIEF theme
# docker run \
#  -e LIEF_VERSION=0.11.0 -e FORCE_RTD_THEME=True \
#  -v $(pwd)/build:/src \
#  liefproject/doc:base sh /src/generate_doc.sh

# Build doc with LIEF theme
# docker run \
#  -e LIEF_VERSION=0.11.0 \
#  -v $(pwd)/build:/src \
#  liefproject/doc:sphinx_lief_theme sh /src/generate_doc.sh

# This stage is used to build the latest version of Doxygen.
# One can use --build-arg doxygen_version=<branch | tag> to build a specific tag or branch
FROM debian:buster-slim AS base

LABEL maintainer="Romain Thomas <me@romainthomas.fr>"
ARG doxygen_version=Release_1_8_20

RUN mkdir -p /usr/share/man/man1 && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      python3 \
      gcc g++ \
      cmake \
      flex \
      bison \
      ninja-build \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git clone -j8 --depth=1 --branch=${doxygen_version} https://github.com/doxygen/doxygen.git && \
    cd doxygen && \
    mkdir build && cd build && \
    cmake -GNinja -Denglish_only=ON .. && \
    ninja && \
    cp bin/doxygen /opt/doxygen && \
    cd / && rm -rf /doxygen


FROM debian:buster-slim AS base
COPY --from=doxygen-builder /opt/doxygen /usr/bin/doxygen

# install dependencies
# See: https://github.com/debuerreotype/docker-debian-artifacts/issues/24#issuecomment-360870939
RUN mkdir -p /usr/share/man/man1 && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      locales \
      python3 python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip \
  --no-cache-dir \
  install \
    sphinx==3.3.1       \
    breathe==4.25.1     \
    Pygments==2.7.3     \
    sphinx_rtd_theme==0.5.0

# configure locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

FROM base AS sphinx_lief_theme

COPY assets/sphinx_lief-1.0.0-py3-none-any.whl /tmp/

RUN python3 -m pip --no-cache-dir install /tmp/sphinx_lief-1.0.0-py3-none-any.whl && \
    rm -rf /tmp/sphinx_lief-1.0.0-py3-none-any.whl


