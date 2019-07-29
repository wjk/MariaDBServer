#!/bin/zsh

set -e

CLEAN=false
while [ $# -gt 0 ]; do
    if [ "$1" = "-clean" ]; then
        CLEAN=true
    else
        echo "Unknown argument $1, ignoring"
    fi

    shift
done

MY_DIR=$(cd `dirname $0` && pwd)
mkdir -p $MY_DIR/build && cd $MY_DIR/build

echo '*** Step 0: Checking prerequisites'

which -s cmake || {
    echo "Error: CMake not found in path" 1>&2
    echo "You can install it via Homebrew: brew install cmake" 1>&2
    exit 1
}

MAKE_PROGRAM=ninja
CMAKE_GENERATOR=Ninja
which -s ninja || {
    echo "Ninja not found, using Make instead (slower)" 1>&2
    echo "You can install it via Homebrew: brew install ninja" 1>&2
    MAKE_PROGRAM=make
    CMAKE_GENERATOR="Unix Makefiles"
}

# OpenSSL is expected to be installed via Homebrew, as that's what I use.
# If you have it installed somewhere else, set the OPENSSL_PREFIX environment
# variable before running this script.
: ${OPENSSL_PREFIX:=/usr/local/opt/openssl}
if [ ! -f $OPENSSL_PREFIX/lib/libcrypto.a -o ! -f $OPENSSL_PREFIX/lib/libssl.a -o ! -d $OPENSSL_PREFIX/include/openssl ]; then
    echo "Error: OpenSSL not found at: ${OPENSSL_PREFIX}" 1>&2
    echo "You can install it via Homebrew: brew install openssl" 1>&2
    exit 1
fi

echo '*** Step 1: Downloading MariaDB'
SOURCE_TARBALL_FILENAME=mariadb-10.4.6.tar.gz

if [ -f "$SOURCE_TARBALL_FILENAME" ]; then
    echo "$SOURCE_TARBALL_FILENAME already downloaded"
else
    echo "Downloading $SOURCE_TARBALL_FILENAME"
    curl -s -L -o $SOURCE_TARBALL_FILENAME https://downloads.mariadb.org/f/mariadb-10.4.6/source/mariadb-10.4.6.tar.gz
    CLEAN=true
fi

SOURCE_SHA=$(shasum -a 256 $SOURCE_TARBALL_FILENAME)
EXPECTED_SHA="a270fe6169a1aaf6f2cbbc945de2c954d818c48e1a0fc02fbed92ecb94678e70  mariadb-10.4.6.tar.gz"
if [ "$SOURCE_SHA" != "$EXPECTED_SHA" ]; then
    echo "Error: SHA-256 checksum does not match for $SOURCE_TARBALL_FILENAME" 1>&2
    echo "Expected: $EXPECTED_SHA" 1>&2
    echo "Actual: $SOURCE_SHA" 1>&2
    exit 1
fi

if [ "$CLEAN" = "true" -o ! -d mariadb-10.4.6 ]; then
    echo "Extracting $SOURCE_TARBALL_FILENAME"
    rm -rf mariadb-10.4.6
    tar xf $SOURCE_TARBALL_FILENAME
    PATCHES_NEEDED=true
fi

cd mariadb-10.4.6

echo '*** Step 2: Applying patches'

if [ -n "$PATCHES_NEEDED" ]; then
    patch -p1 -N -r /dev/null < $MY_DIR/patches/0001-install_db_path.patch
    patch -p1 -N -r /dev/null < $MY_DIR/patches/0002-wsrep_sst_common.patch
fi

echo '*** Step 3: Compiling MariaDB'
# The values for the -DINSTALL_* variables are relative to the prefix.
cmake . -Wno-dev -G "${CMAKE_GENERATOR}" \
    -DCMAKE_C_FLAGS_RELEASE=-DNDEBUG \
    -DCMAKE_CXX_FLAGS_RELEASE=-DNDEBUG \
    -DCMAKE_INSTALL_PREFIX=/Library/MariaDB/Prefix \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DMYSQL_DATADIR=/Library/MariaDB/ServiceData \
    -DINSTALL_INCLUDEDIR=include/mysql \
    -DINSTALL_MANDIR=share/man \
    -DINSTALL_DOCDIR=share/doc \
    -DINSTALL_INFODIR=share/info \
    -DINSTALL_MYSQLSHAREDIR=share/mysql \
    -DWITH_PCRE=bundled \
    -DWITH_READLINE=yes \
    -DWITH_SSL=$OPENSSL_PREFIX \
    -DWITH_UNIT_TESTS=OFF \
    -DDEFAULT_CHARSET=utf8mb4 \
    -DDEFAULT_CHARSET=utf8mb4_general_ci \
    -DINSTALL_SYSCONFDIR=/Library/MariaDB/Configuration \
    -DINSTALL_MYSQLTESTDIR=NO \
    -DINSTALL_SQLBENCHDIR=NO \
    -DPLUGIN_TOKUDB=NO \
    -DOPENSSL_SSL_LIBRARY=${OPENSSL_PREFIX}/lib/libssl.a \
    -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_PREFIX}/lib/libcrypto.a \
    -DCOMPILATION_COMMENT="Sunburst MariaDB Server"

$MAKE_PROGRAM
