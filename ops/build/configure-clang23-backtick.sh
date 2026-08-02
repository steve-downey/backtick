#!/usr/bin/env bash
# Reproduces the CMake configuration for the backtick-23 Clang build
# (track: backtick-23, worktree ~/src/llvm/backtick, base upstream/release/23.x).
#
# Installs into a private, version-suffixed prefix instead of /usr/local, so
# it can coexist with a vanilla ~/install/llvm-23. The real binary is named
# clang-<major>-backtick (e.g. clang-23-backtick), with clang/clang++ symlinks
# in the same bin/, exactly like the existing ~/install/llvm-23 convention.
#
# compiler-rt is in LLVM_ENABLE_RUNTIMES so the installed clang can link
# -fsanitize= builds; without it the sanitizer configs of any project using
# this toolchain (e.g. examples/'s default CONFIG=Asan) fail at link time
# with "cannot find libclang_rt.asan.a".
#
# Usage: run from a fresh, empty build directory:
#   mkdir -p ~/src/llvm/build-backtick && cd ~/src/llvm/build-backtick
#   ~/src/backtick/ops/build/configure-clang23-backtick.sh
#   ninja install
#
# To reconfigure an existing build directory in place (cheap: only the
# install prefix and the clang target's VERSION property change, so this
# does not force a full rebuild):
#   cd ~/src/llvm/build-backtick && ~/src/backtick/ops/build/configure-clang23-backtick.sh
#
# Override the source tree or install prefix if needed:
#   CLANG23_BACKTICK_PREFIX=/somewhere/else configure-clang23-backtick.sh /path/to/backtick/llvm
set -euo pipefail

SRC_DIR="${1:-$HOME/src/llvm/backtick/llvm}"
INSTALL_PREFIX="${CLANG23_BACKTICK_PREFIX:-$HOME/install/clang-23-backtick}"

VERSION_FILE="$SRC_DIR/../cmake/Modules/LLVMVersion.cmake"
LLVM_MAJOR="$(grep -m1 'set(LLVM_VERSION_MAJOR' "$VERSION_FILE" | grep -oE '[0-9]+')"
if [ -z "$LLVM_MAJOR" ]; then
  echo "error: could not determine LLVM_VERSION_MAJOR from $VERSION_FILE" >&2
  exit 1
fi

set -x
exec cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang-23 \
  -DCMAKE_CXX_COMPILER=clang++-23 \
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
  -DLLVM_ENABLE_RUNTIMES="compiler-rt" \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_TARGETS_TO_BUILD=host \
  -DLLVM_PARALLEL_COMPILE_JOBS=12 \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
  -DCLANG_EXECUTABLE_VERSION="${LLVM_MAJOR}-backtick" \
  "$SRC_DIR"
