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

# Setup LIEF doc assets
cp LIEF-master/examples/cmake/find_package/CMakeLists.txt     LIEF-master/doc/sphinx/_static/CMakeFindPackage.cmake
cp LIEF-master/examples/cmake/find_package/README.rst         LIEF-master/doc/sphinx/_static/ReadmeFindPackage.rst
cp LIEF-master/examples/cmake/external_project/CMakeLists.txt LIEF-master/doc/sphinx/_static/CMakeExternalProject.cmake
cp LIEF-master/examples/cmake/external_project/README.rst     LIEF-master/doc/sphinx/_static/ReadmeExternalProject.rst

# Doxygen
# =======================================================================

# TODO(romain): To update when it will be merged in master
curl -LO https://gist.githubusercontent.com/romainthomas/1ffc98fa20216a09b28baa305af048a4/raw/55b80ef5dfa1ea9a637d2cf48500019d755737ee/Doxyfile

LIEF_INPUT=LIEF-${LIEF_VERSION}-Linux/include/LIEF \
LIEF_EXCLUDE=LIEF-${LIEF_VERSION}-Linux/include/LIEF/third-party \
LIEF_INCLUDE_PATH=LIEF-${LIEF_VERSION}-Linux/include \
doxygen Doxyfile

# Sphinx
# =======================================================================

cd LIEF-master/doc
# TODO(romain): To update when it will be merged in master
curl -LO https://gist.githubusercontent.com/romainthomas/8a503a1f3c13862e1339a8f61e679fbf/raw/3fda36bdcb00b8c28ff70f8386ea07cdb2bb75dc/conf.py
mv conf.py sphinx/

LIEF_DOXYGEN_XML=$HOME/doxygen/xml/ \
sphinx-build -a -E -j8 -w sphinx-warn.log ./sphinx ./sphinx-doc

# Deploy
# =======================================================================
mv sphinx-doc /src/doc
mv $HOME/doxygen/html /src/doc/doxygen
chmod -R 777 /src/ && \
  chown 1000:1000 /src/doc && \
  chown -R 1000:1000 /src/doc/*



