#!/usr/bin/env bash
# Builds the LLVM a KLF distribution carries from this checkout, and packs it.
#
#   ridl/build.sh <build-dir> <install-dir> <archive>
#
# Only what KLF runs ships: clang, which links every program; lld, which it
# links with on every host; llvm-ar, llvm-strip and llvm-objcopy; llvm-nm and
# llvm-dwarfdump, which its tests read objects with; and clang's own headers.
# The tools are linked against libLLVM, which ships beside them.
set -euo pipefail
BUILD=$1 INSTALL=$2 ARCHIVE=$3
SOURCE=$(cd "$(dirname "$0")/.." && pwd)

COMPONENTS="clang;clang-resource-headers;lld;llvm-ar;llvm-strip;llvm-objcopy;llvm-nm;llvm-dwarfdump;LLVM"
RPATH='$ORIGIN/../lib'
[ "$(uname -s)" = Darwin ] && RPATH='@loader_path/../lib'

cmake -S "$SOURCE/llvm" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_RPATH="$RPATH" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="X86;AArch64;WebAssembly" \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DLLVM_DISTRIBUTION_COMPONENTS="$COMPONENTS" \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=OFF \
    -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
    -DCLANG_ENABLE_ARCMT=OFF \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_ZLIB=OFF \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF
cmake --build "$BUILD" --target install-distribution-stripped

# lld picks its flavour from the name it runs under, and clang runs it as
# `ld64.lld` on a Mac and `ld.lld` elsewhere.
for name in ld.lld ld64.lld lld-link wasm-ld; do
    [ -e "$INSTALL/bin/$name" ] || ln -s lld "$INSTALL/bin/$name"
done
[ -e "$INSTALL/bin/clang++" ] || ln -s clang "$INSTALL/bin/clang++"

"$INSTALL/bin/clang" --version
mkdir -p "$(dirname "$ARCHIVE")"
tar -C "$INSTALL" -cJf "$ARCHIVE" .
