#!/bin/zsh

set -e

MY_DIR=$(cd `dirname $0` && pwd)
mkdir -p $MY_DIR/build && cd $MY_DIR/build

echo '*** Step 0: Checking prerequisites'

which -s cmake || {
    echo "Error: CMake not found in path" 1>&2
    echo "You can install it via Homebrew: brew install cmake" 1>&2
    exit 1
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
    curl -s -L -o $SOURCE_TARBALL_FILENAME https://downloads.mariadb.org/f/mariadb-10.4.6/source/mariadb-10.4.6.tar.gz
fi

SOURCE_SHA=$(shasum -a 256 $SOURCE_TARBALL_FILENAME)
EXPECTED_SHA="a270fe6169a1aaf6f2cbbc945de2c954d818c48e1a0fc02fbed92ecb94678e70  mariadb-10.4.6.tar.gz"
if [ "$SOURCE_SHA" != "$EXPECTED_SHA" ]; then
    echo "Error: SHA-256 checksum does not match for $SOURCE_TARBALL_FILENAME" 1>&2
    echo "Expected: $EXPECTED_SHA" 1>&2
    echo "Actual: $SOURCE_SHA" 1>&2
    exit 1
fi

echo "Extracting $SOURCE_TARBALL_FILENAME"
rm -rf mariadb-10.4.6
tar xf $SOURCE_TARBALL_FILENAME
cd mariadb-10.4.6
