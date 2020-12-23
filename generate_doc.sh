#!/usr/bin/sh
set -ex

# Install
# =======================================================================

# Install latest LIEF Python version
cd $HOME
python3 -m pip install --no-cache-dir --index-url https://lief-project.github.io/packages lief==${LIEF_VERSION}.dev0

# Install SDK
curl https://lief-project.github.io/packages/sdk/LIEF-${LIEF_VERSION}-Linux.tar.gz -LOJ
tar -xvf LIEF-${LIEF_VERSION}-Linux.tar.gz

# Download LIEF src
curl -LO https://github.com/lief-project/LIEF/archive/master.tar.gz
tar -xvf master.tar.gz

# Doxygen
# =======================================================================

LIEF_INPUT=LIEF-${LIEF_VERSION}-Linux/include/LIEF \
LIEF_EXCLUDE=LIEF-${LIEF_VERSION}-Linux/include/LIEF/third-party \
LIEF_INCLUDE_PATH=LIEF-${LIEF_VERSION}-Linux/include \
doxygen LIEF-master/doc/doxygen/Doxyfile

# Sphinx
# =======================================================================

cd LIEF-master/doc
LIEF_DOXYGEN_XML=$HOME/doxygen/xml/ \
sphinx-build -a -E -j8 -w sphinx-warn.log ./sphinx ./sphinx-doc

# Deploy
# =======================================================================
mv sphinx-doc /src/doc
mv $HOME/doxygen/html /src/doc/doxygen
chmod -R 777 /src/ && \
  chown 1000:1000 /src/doc && \
  chown -R 1000:1000 /src/doc/*



