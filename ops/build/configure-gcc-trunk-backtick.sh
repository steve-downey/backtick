#!/usr/bin/env bash
# Reproduces the ./configure invocation for the GCC backtick dev build
# (branch backtick, worktree ~/bld/gcc/gcc-backtick, base GCC trunk).
#
# Installs into a private, version-suffixed prefix instead of the
# build-dir-local install/ directory. --program-suffix is GCC's native
# mechanism for this, matching the existing ~/install/gcc-17 convention
# (gcc-17, g++-17, gcov-17, ...) with a -backtick qualifier appended.
#
# Usage: run from a fresh, empty build directory:
#   mkdir -p ~/bld/gcc/gcc-backtick-build && cd ~/bld/gcc/gcc-backtick-build
#   ~/src/backtick/ops/build/configure-gcc-trunk-backtick.sh
#   make -j18 all-gcc          # build cc1plus for quick -fsyntax-only checks
#   make -j18 install-gcc      # or `make install` for the full toolchain
#
# GCC's ./configure cannot be safely re-run in place against a build
# directory that already has object files from a *different* configuration;
# for a suffix/prefix-only change on an existing tree, re-running configure
# in the same build dir is fine (it only affects install rules), but when in
# doubt, configure a fresh build directory instead.
#
# Override the source tree or install prefix if needed:
#   GCC_TRUNK_BACKTICK_PREFIX=/somewhere/else configure-gcc-trunk-backtick.sh /path/to/gcc-backtick
set -euo pipefail

SRC_DIR="${1:-$HOME/bld/gcc/gcc-backtick}"
INSTALL_PREFIX="${GCC_TRUNK_BACKTICK_PREFIX:-$HOME/install/gcc-trunk-backtick}"

GCC_MAJOR="$(cut -d. -f1 "$SRC_DIR/gcc/BASE-VER")"
if [ -z "$GCC_MAJOR" ]; then
  echo "error: could not determine GCC major version from $SRC_DIR/gcc/BASE-VER" >&2
  exit 1
fi

set -x
exec "$SRC_DIR/configure" \
  --prefix="$INSTALL_PREFIX" \
  --enable-languages=c,c++ \
  --disable-bootstrap \
  --disable-multilib \
  --program-suffix="-${GCC_MAJOR}-backtick"
