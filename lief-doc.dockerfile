# Docker file used to build the LIEF documentation
# ================================================

# This stage is used to build the latest version of Doxygen.
# One can use --build-arg doxygen_version=<branch | tag> to build a specific tag or branch
FROM debian:bookworm-slim AS doxygen-builder

LABEL maintainer="Romain Thomas <me@romainthomas.fr>"
ARG doxygen_version=Release_1_9_8

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
    cmake -GNinja -Denglish_only=ON -S doxygen -B /build && \
    ninja -C /build                        && \
    cp /build/bin/doxygen /opt/doxygen     && \
    strip /opt/doxygen                     && \
    rm -rf /doxygen && rm -rf /build


# =============================================================================
FROM debian:bookworm-slim AS sphinx-lief-theme
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

RUN python3 -m pip install --no-cache-dir --break-system-packages --upgrade pip && \
    python3 -m pip --no-cache-dir install --break-system-packages \
    requests==2.31.0 \
    sphinx==7.2.6    \
    Pygments==2.16.1 \
    breathe==4.35.0

# configure locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ARG sphinx_lief_version=1.0.1

COPY assets/sphinx_lief-1.0.1-py3-none-any.whl /tmp/

RUN mkdir -p ~/.config/pip && \
    echo "[global]\nbreak-system-packages = true\n" > ~/.config/pip/pip.conf && \
    python3 -m pip --no-cache-dir install /tmp/sphinx_lief-${sphinx_lief_version}-py3-none-any.whl && \
    rm -rf /tmp/sphinx_lief-${sphinx_lief_version}-py3-none-any.whl

RUN useradd -m lief-doc
USER lief-doc
