#! /bin/bash

#
# Copyright (C) 2026 Samuel Zormeister, All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

set -e

HOSTS_LIST=`echo $RC_ARCHS | sed 's/[[:space:]]/;/g'`

BASE_DEFINITIONS="	\
				   -DLLVM_ENABLE_ASSERTIONS=OFF"

VERSIONING_DEFINITIONS="-DLLVM_VERSION_INFO=${RC_ProjectNameAndSourceVersion} \
					    -DLLVM_VERSION_MAJOR=11		\
						-DLLVM_VERSION_MINOR=0		\
						-DLLVM_VERSION_PATCH=0		\
						-DLLVM_VERSION_SUFFIX=\"\""	

BOOTSTRAP_DEFINITIONS="	\
					   -DBOOTSTRAP_LLVM_ENABLE_LIBCXX=ON				\
				       -DBOOTSTRAP_LLVM_INCLUDE_TESTS=OFF \
    				   -DBOOTSTRAP_LLVM_INCLUDE_UTILS=OFF \
    				   -DBOOTSTRAP_CLANG_INCLUDE_TESTS=OFF"

function progress() {
    echo "*******************************"
    echo "* $1"
    echo "*******************************"
}

function run() {
    local arg
    {
        printf "*"
        for arg in "$@"; do
            printf " %q" "$arg"
        done
        printf "\n"
    } >&2

    "$@"
}

function build() {
    NINJA=`xcrun -f ninja`
    CLANG=`xcrun -sdk ${SDKROOT} -f clang`
    CLANGXX=`xcrun -sdk ${SDKROOT} -f clang++`
    SYSROOT=`xcrun -sdk ${SDKROOT} --show-sdk-path`
    GENERATOR=Ninja
    VERBOSE="-v"

    SDK_VERSION=`xcrun -sdk ${SYSROOT} --show-sdk-version | awk -F. '{print $1}'`

    if [ "$SDK_VERSION" -ge "13" ]; then
        INSTALL_LIBCXX_HEADERS=NO
        LLVM_ENABLE_PROJECTS="clang;clang-tools-extra"
        LIBCXX_DEFINITIONS=""
    else
        INSTALL_LIBCXX_HEADERS=YES
        LLVM_ENABLE_PROJECTS="clang;clang-tools-extra;libcxx"
        LIBCXX_DEFINITIONS="-DLIBCXX_INSTALL_LIBRARY=NO \
                            -DLIBCXX_INSTALL_HEADERS=YES"
    fi

    echo "*******************************"
    echo "* Initiating clang build for archs: ${RC_ARCHS} "
    echo "* "
    echo "* Host OS Version          | ${HOST_VERSION}"
    echo "* Disabled libc++ Headers  | ${INSTALL_LIBCXX_HEADERS}"
    echo "* "
    echo "* RC_ProjectName           | ${RC_ProjectName} "
    echo "* RC_ProjectSourceVersion  | ${RC_ProjectSourceVersion} "
    echo "* "
    echo "* DSTROOT                  | ${DSTROOT} "
    echo "* OBJROOT                  | ${OBJROOT} "
    echo "* SRCROOT                  | ${SRCROOT} "
    echo "*******************************"

    progress "Starting LLVM build."

    run mkdir -p "${OBJROOT}/obj-llvm"
    run pushd "${OBJROOT}/obj-llvm/"
    run xcrun cmake "${SRCROOT}"/llvm  \
        -G "${GENERATOR}"   \
        -C "${SRCROOT}/clang/cmake/caches/NeoDarwin-stage1.cmake"   \
        -DCMAKE_MAKE_PROGRAM=${NINJA} \
        -DCMAKE_C_COMPILER=${CLANG} \
        -DCMAKE_CXX_COMPILER=${CLANGXX} \
        -DCMAKE_INSTALL_PREFIX="${OBJROOT}/llvm-temp-install" \
        -DCMAKE_OSX_SYSROOT="${SYSROOT}" \
        -DCMAKE_OSX_ARCHITECTURES="${HOST_ARCHS}" \
        -DLLVM_ENABLE_PROJECTS=${LLVM_ENABLE_PROJECTS} \
        -DINSTALL_LIBCXX_HEADERS=${INSTALL_LIBCXX_HEADERS} \
        $BASE_DEFINITIONS   \
        $LIBCXX_DEFINITIONS \
        $VERSIONING_DEFINITIONS \
        $BOOTSTRAP_DEFINITIONS
    run popd
    run xcrun cmake --build "${OBJROOT}/obj-llvm" \
                    --target stage2-install-distribution    \
                    -- -v
}

build
