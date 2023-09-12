#!/bin/bash -xe
set -xe

source share/pins.txt
source share/scripts/helper-functions.sh

function package(){
    parseArgs $@

    local library="ssh2"
    local rsync="rsync -uav --progress"
    local builddir="/tmp/${library}/${target}-build" # $(mktemp -d)/installs
    $rsync ${target}-build/* ${builddir}/

    local installsdir="${builddir}/installs" 
    mkdir -p ${installsdir}
    rm -fr ${installsdir}/*
    mkdir -p "${installsdir}/lib"
    mkdir -p "${installsdir}/include"

    pushd "${builddir}"
    $rsync --include="*/"  --include="*.h" --exclude="*" ./ ${installsdir}/
    if [ "$target" == "mingw" ]; then
        $rsync --include="*/"  --include="*.dll*" --exclude="*" ./ ${installsdir}/
    else
        $rsync --include="*/"  --include="*.so*" --exclude="*" ./ ${installsdir}/
    fi
    popd

    compressInstalls library=${library} target=${target} builddir="${builddir}"
    # zip utils.zip "${installsdir}"
}

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
            -DCMAKE_BUILD_TYPE=ReleaseWithDebug \
            -DCMAKE_MODULE_PATH="${cmake_modules_path}" \
            -DCMAKE_PREFIX_PATH="${cmake_modules_path}" \
            -G Ninja ..
    elif [ "$target" == "arm" ]; then
        source "${SDK_DIR}/environment-setup-cortexa72-oe-linux"
            # -DUSE_FRAMEBUFFER=1 \
            # -DUSE_WAYLAND=0 \
        cmake \
            -DCMAKE_BUILD_TYPE=ReleaseWithDebug \
            -DCMAKE_MODULE_PATH="${cmake_modules_path}" \
            -DCMAKE_PREFIX_PATH="${cmake_modules_path}" \
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
            -G "Ninja" ..
    else
        echo "FATAL: bad target ${target}"
        exit -1
    fi
    ninja --verbose
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

function installDeps() {
    local target="x86"
    parseArgs $@
    local builddir="${target}-build"
    local artifacts_url="/home/$USER/downloads"

    local libs=(openssl)
    for library in "${libs[@]}"; do
        local pin="${library}_pin"
        # echo "${!pin}" #gets the value of variable where the variable name is "${library}_pin"
        local artifacts_file="${library}-${!pin}-${target}.tar.xz"
        installLib $@ library="${library}" artifacts_file="${artifacts_file}" artifacts_url="${artifacts_url}" 
    done
}

function main(){
    local target="x86"
    parseArgs $@
    cleanBuild $@
    installDeps $@
    build target="$target" clean="$clean"
    package target="$target"
}

time main $@

