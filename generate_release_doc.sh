#!/usr/bin/sh
set -ex

# Install
# =======================================================================

# Install latest LIEF Python version
cd $HOME
python3 -m pip install --no-cache-dir --index-url --force-reinstall \
        https://lief.s3-website.fr-par.scw.cloud/${LIEF_VERSION} lief==${LIEF_VERSION}

# Install SDK
curl https://lief.s3-website.fr-par.scw.cloud/${LIEF_VERSION}/sdk/LIEF-${LIEF_VERSION}-Linux-x86_64.tar.gz -LOJ
tar -xvf LIEF-${LIEF_VERSION}-Linux-x86_64.tar.gz

# Download LIEF src
curl -LO https://github.com/lief-project/LIEF/archive/refs/tags/${LIEF_VERSION}.tar.gz
tar -xvf ${LIEF_VERSION}.tar.gz

# Doxygen
# =======================================================================
LIEF_INPUT="LIEF-${LIEF_VERSION}/doc/doxygen LIEF-${LIEF_VERSION}-Linux-x86_64/include/LIEF" \
LIEF_EXCLUDE="LIEF-${LIEF_VERSION}-Linux-x86_64/include/LIEF/third-party" \
LIEF_INCLUDE_PATH="LIEF-${LIEF_VERSION}-Linux-x86_64/include/" \
LIEF_DOXYGEN_WARN_FILE="/tmp/doxygen-warn.log" \
doxygen LIEF-${LIEF_VERSION}/doc/doxygen/Doxyfile

# Sphinx
# =======================================================================

cd LIEF-${LIEF_VERSION}/doc

LIEF_DOXYGEN_XML="$HOME/doxygen/xml/" \
sphinx-build -a -E -j8 -w /tmp/sphinx-warn.log ./sphinx ./sphinx-doc

# Deploy
# =======================================================================
mv sphinx-doc /src/doc
mv $HOME/doxygen/html /src/doc/doxygen

mv /tmp/sphinx-warn.log /src/
mv /tmp/doxygen-warn.log /src/


chmod -R 777 /src/ && \
  chown 1000:1000 /src/doc && \
  chown -R 1000:1000 /src/doc/*



