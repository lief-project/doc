# Docker file used to build the LIEF documentation
# ================================================
#
# 1. Building the Docker image
#
#    docker buildx build --target base -t liefproject/doc:base -f ./lief-doc.dockerfile .
#    docker buildx build --target sphinx_lief_theme --tag liefproject/doc:sphinx_lief_theme -f ./lief-doc.dockerfile .
#
# mkdir -p build && cp generate_doc.sh build/ && chmod 777 build/generate_doc.sh
#
# 2.1 Build doc WITHOUT LIEF theme
#
#     docker run \
#      -e LIEF_VERSION=0.11.0 -e FORCE_RTD_THEME=True \
#      -v $(pwd)/build:/src \
#      liefproject/doc:base sh /src/generate_doc.sh
#
# 2.2 Build doc with LIEF theme
#
#     docker run \
#      -e LIEF_VERSION=0.11.0 \
#      -v $(pwd)/build:/src \
#      liefproject/doc:sphinx_lief_theme sh /src/generate_doc.sh
#
# ================================================

# This stage is used to build the latest version of Doxygen.
# One can use --build-arg doxygen_version=<branch | tag> to build a specific tag or branch
FROM debian:bookworm-slim AS doxygen-builder

LABEL maintainer="Romain Thomas <me@romainthomas.fr>"
ARG doxygen_version=Release_1_9_7

RUN mkdir -p /usr/share/man/man1 &&            \
    apt-get update -y &&                       \
    apt-get install -y --no-install-recommends \
      ca-certificates                          \
      curl                                     \
      git                                      \
      python3                                  \
      gcc g++                                  \
      cmake                                    \
      flex                                     \
      bison                                    \
      ninja-build                              \
    && apt-get clean                           \
    && rm -rf /var/lib/apt/lists/*

RUN git clone -j8 --depth=1 --branch=${doxygen_version} https://github.com/doxygen/doxygen.git && \
    cd doxygen                         && \
    mkdir build                        && \
    cd build                           && \
    cmake -GNinja -Denglish_only=ON .. && \
    ninja                              && \
    cp bin/doxygen /opt/doxygen        && \
    cd / && rm -rf /doxygen


FROM debian:bookworm-slim AS sphinx_lief_theme
COPY --from=doxygen-builder /opt/doxygen /usr/bin/doxygen

# install dependencies
# See: https://github.com/debuerreotype/docker-debian-artifacts/issues/24#issuecomment-360870939
RUN mkdir -p /usr/share/man/man1 &&            \
    apt-get update -y &&                       \
    apt-get install -y --no-install-recommends \
      ca-certificates                          \
      curl                                     \
      locales                                  \
      graphviz                                 \
      git                                      \
      python3 python3-pip                      \
    && apt-get clean                           \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --break-system-packages --upgrade pip
RUN python3 -m pip --no-cache-dir install --break-system-packages \
    requests==2.31.0                       \
    sphinx==7.0.1                          \
    Pygments==2.15.1                       \
    breathe==4.35.0
    #git+https://github.com/breathe-doc/breathe.git@b4564e9b7f654cc23907f4e346ed79f1447a9cba
    # Install not yet released version of breath to support sphinx 6.x.x

# configure locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

COPY assets/sphinx_lief-1.0.0-py3-none-any.whl /tmp/

RUN mkdir -p ~/.config/pip && \
    echo "[global]\nbreak-system-packages = true\n" > ~/.config/pip/pip.conf
RUN python3 -m pip --no-cache-dir install  /tmp/sphinx_lief-1.0.0-py3-none-any.whl && \
    rm -rf /tmp/sphinx_lief-1.0.0-py3-none-any.whl



