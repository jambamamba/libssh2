#!/bin/bash -xe
set -xe

source share/pins.txt
source share/scripts/helper-functions.sh

function build(){
    local target="x86"
    parseArgs $@

    local srcdir="$(pwd)"
    local cmake_modules_path="${srcdir}/share/cmake-modules"
    local builddir="${target}-build"
    mkdir -p "${builddir}"
    pushd "${builddir}"
    if [ "$target" == "x86" ]; then
        cmake \
            -DCMAKE_BUILD_TYPE=RelWithDebugInfo \
            -DCMAKE_INSTALL_PREFIX=/usr/local \
            -DCMAKE_MODULE_PATH="/usr/local/cmake" \
            -DCMAKE_PREFIX_PATH="/usr/local/cmake" \
            -DTARGET=${target} \
            -G Ninja ..
    elif [ "$target" == "arm" ]; then
        source "${SDK_DIR}/environment-setup-cortexa72-oe-linux"
            # -DUSE_FRAMEBUFFER=1 \
            # -DUSE_WAYLAND=0 \
        cmake \
            -DCMAKE_BUILD_TYPE=ReleaseWithDebug \
            -DCMAKE_MODULE_PATH="${cmake_modules_path}" \
            -DCMAKE_PREFIX_PATH="${cmake_modules_path}" \
            -DTARGET=${target} \
            -G "Ninja" ..
    elif [ "$target" == "mingw" ]; then
        source "${srcdir}/share/toolchains/x86_64-w64-mingw32.sh"
        cmake \
            -DCMAKE_MODULE_PATH="${cmake_modules_path}" \
            -DCMAKE_PREFIX_PATH="${cmake_modules_path}" \
            -DUSE_SDL=1 \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_SKIP_RPATH=TRUE \
            -DCMAKE_SKIP_INSTALL_RPATH=TRUE \
            -DWIN32=TRUE \
            -DMINGW64=${MINGW64} \
            -DWITH_GCRYPT=OFF \
            -DWITH_MBEDTLS=OFF \
            -DHAVE_STRTOULL=1 \
            -DHAVE_COMPILER__FUNCTION__=1 \
            -DHAVE_GETADDRINFO=1 \
            -DENABLE_CUSTOM_COMPILER_FLAGS=OFF \
            -DBUILD_CLAR=OFF \
            -DTHREADSAFE=ON \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER=$CC \
            -DCMAKE_RC_COMPILER=$RESCOMP \
            -DDLLTOOL=$DLLTOOL \
            -DCMAKE_FIND_ROOT_PATH=/usr/x86_64-w64-mingw32 \
            -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
            -DCMAKE_INSTALL_PREFIX=../install-win \
            -DTARGET=${target} \
            -G "Ninja" ..
    else
        echo "FATAL: bad target ${target}"
        exit -1
    fi
    ninja #--verbose
    sudo ninja install && sudo chown $(id -u):$(id -g) install_manifest.txt
    popd
}

function cleanBuild() {
    local target="x86"
    parseArgs $@
    local builddir="${target}-build"
    mkdir -p "${builddir}"
    pushd "${builddir}"
    if [ "$clean" == "true" ]; then
        rm -fr *
    fi
    popd
}

function main(){
    local target="x86"
    parseArgs $@
    cleanBuild $@
    # installDeps $@
    build target="$target" clean="$clean"
    package target="$target" dst="/downloads"
}

time main $@

