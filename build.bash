#!/usr/bin/env bash

DEBIAN_PACKAGE_NAME=sac-iris
VERSION=101.6a
VERSION_DEBPREFIX=
VERSION_DEBSUFFIX=-1+sdp1.0
SOURCE_TARBALL_NAME=sac-"$VERSION"-source.tar.gz
SOURCE_REQUIRED_CHECKSUMS="10e718c78cbbed405cce5b61053f511c670a85d986ee81d45741f38fcf6b57d5"
ARCH=arm64
BUILD_ROOT=$(pwd)

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
    printf "SAC Debian/Ubuntu Packager ver $VERSION_DEBPREFIX$VERSION$VERSION_DEBSUFFIX\n"
    printf "\n"
    printf "usage: \n"
    printf "    -v, --verbose: show more detail message while building\n"
    printf "    -V, --version: show more detail message while building\n"
    printf "    --help: show this help\n"
    printf "\n"
    exit 0
fi

if [ "$1" == "-V" ] || [ "$1" == "--version" ]
then
    printf "SAC Debian/Ubuntu Packager ver $VERSION_DEBPREFIX$VERSION$VERSION_DEBSUFFIX\n"
    printf "\n"
    exit 0
fi

if [ "$1" ==  "-v" ] || [ "$1" ==  "--verbose" ]
then
    QUIET=""
    LN_ARGUMENT="-rsv"
    RM_ARGUMENT="-v"
else
    QUIET="--quiet"
    LN_ARGUMENT="-rs"
    RM_ARGUMENT=""
fi

function check_distribution() {
    DISTRO_NAME=$(grep PRETTY_NAME /etc/os-release|awk -F'=' '{print $2}')
    case $DISTRO_NAME in
        '"Debian GNU/Linux 9 (stretch)"')
            DEPENDENCIES="x11-apps, libncurses5, libreadline7"
            VERSION_DEBSUFFIX=$VERSION_DEBSUFFIX"debian9"
            ;;
        '"Debian GNU/Linux 10 (buster)"')
            DEPENDENCIES="x11-apps, libncurses6, libreadline7"
            VERSION_DEBSUFFIX=$VERSION_DEBSUFFIX"debian10"
            ;;
        '"Ubuntu 16.04'*)
            DEPENDENCIES="x11-apps, libncurses5, libreadline6"
            VERSION_DEBSUFFIX=$VERSION_DEBSUFFIX"ubuntu16"
            ;;
        '"Ubuntu 18.04'*)
            DEPENDENCIES="x11-apps, libncurses5, libreadline7"
            VERSION_DEBSUFFIX=$VERSION_DEBSUFFIX"ubuntu18"
            ;;
        '"Ubuntu 20.04'*)
            DEPENDENCIES="x11-apps, libncurses6, libreadline8"
            VERSION_DEBSUFFIX=$VERSION_DEBSUFFIX"ubuntu20"
            ;;
        *)
            printf "\033[1;31m   x Sorry, we don't support this distribution for packaging!\033[0m\n"
            exit 1
            ;;
    esac
}

set -eu

printf "\033[1;36mSAC Debian/Ubuntu Packager ver $VERSION_DEBPREFIX$VERSION$VERSION_DEBSUFFIX\033[0m\n"
printf "\033[1;33m+ Starting Build in $BUILD_ROOT ...\033[0m\n"
printf "\033[1m+ Cleaning previous build...\033[0m\n"
test -d pkgroot && rm -r pkgroot
test -e *.deb && rm *.deb
test -e sac-"$VERSION" && rm -r sac-"$VERSION"
mkdir -p pkgroot/DEBIAN
mkdir -p pkgroot/usr/bin
mkdir -p pkgroot/usr/share/sac/scripts
mkdir -p pkgroot/etc/profile.d
mkdir -p pkgroot/etc/csh/login.d
mkdir -p pkgroot/opt/sac
printf "\033[1;32m    - Done!\033[0m\n"

printf "\033[1m+ Checking source tarball ( $PWD/$SOURCE_TARBALL_NAME )...\033[0m\n"
( test -e "$SOURCE_TARBALL_NAME" && (>&2 printf "\033[1;32m    - Tarball exists!\033[0m\n") ) ||
    ( printf "\033[1;31m   x Tarball does not exist or filename was wrong!\033[0m\n" && exit 1)
sha256_this_tarball=$(sha256sum $SOURCE_TARBALL_NAME | awk '{print $1}')
( test "$SOURCE_REQUIRED_CHECKSUMS" = "$sha256_this_tarball" && (>&2 printf "\033[1;32m    - Tarball checksums is right!\033[0m\n") ) ||
    ( printf "\033[1;31m   x Tarball's checksums was wrong! Maybe you use the wrong file.\033[0m\n" && exit 1)

printf "\033[1m+ Extracting...\033[0m\n"
tar -zxf "$SOURCE_TARBALL_NAME"
printf "\033[1;32m    - Done!\033[0m\n"

printf "\033[1m+ Preparing for configuration...\033[0m\n"
cd "$BUILD_ROOT"/sac-"$VERSION"
patch $QUIET -p1 < ../0001-Fix-missing-DESTDIR-variable-in-Makefile.patch
patch $QUIET -p1 < ../0001-Let-libedit-use-main-repo-s-cross-compile-config.patch
rm $RM_ARGUMENT bin/sac-config bin/sacinit.csh bin/sacinit.sh
wget -O config/config.guess 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
wget -O config/config.sub 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
chmod +x config/config.guess config/config.sub
./configure --prefix="/opt/sac" --build=x86_64-liunx-gnu --host=aarch64-unknown-linux-gnu LDFLAGS='-static' $QUIET
printf "\033[1;32m    - Done!\033[0m\n"

printf "\033[1m+ Compiling...\033[0m\n"
make -j$(nproc) $QUIET
printf "\033[1;32m    - Done!\033[0m\n"

printf "\033[1;32m+ Adding program to distro path...\033[0m\n"
make DESTDIR="$BUILD_ROOT"/pkgroot $QUIET install
cd "$BUILD_ROOT"
ln $LN_ARGUMENT pkgroot/opt/sac/bin/sac pkgroot/usr/bin/sac
ln $LN_ARGUMENT pkgroot/opt/sac/bin/sacinit.sh pkgroot/etc/profile.d/sac_bash_profile.sh
ln $LN_ARGUMENT pkgroot/opt/sac/bin/sacinit.csh pkgroot/etc/csh/login.d/sacinit.csh

printf "\033[1;32m+ Generating Debian/Ubuntu packaging control file...\033[0m\n"
check_distribution
cat > pkgroot/DEBIAN/control <<EOF
Package: $DEBIAN_PACKAGE_NAME
Version: $VERSION_DEBPREFIX$VERSION$VERSION_DEBSUFFIX
Section: utils
Priority: optional
Maintainer: Sean Ho <sean.li.shin.ho@gmail.com>
Architecture: $ARCH
Depends: $DEPENDENCIES
Homepage: https://ds.iris.edu/ds/nodes/dmc/software/downloads/sac/
Description: Debian/Ubuntu format package for Seismic Analysis Code by IRIS
 This package is generated by third party packaging scripts
 Distributions of binary or source code are restricted.
 You can NOT upload this binary package in public.
 To get the related source code or binary builds from IRIS,
 you have to request it from: http://ds.iris.edu/ds/nodes/dmc/forms/sac/
EOF

printf "\033[1;32m+ Use dpkg-deb to generate Debian/Ubuntu package...\033[0m\n"
fakeroot dpkg-deb --build pkgroot "$DEBIAN_PACKAGE_NAME"-""$VERSION_DEBPREFIX"$VERSION""$VERSION_DEBSUFFIX"_"$ARCH".deb
