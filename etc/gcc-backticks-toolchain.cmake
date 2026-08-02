# etc/gcc-backticks-toolchain.cmake                                 -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# The infix-backtick prototype built on GCC trunk (branch backtick),
# installed by ops/build/configure-gcc-trunk-backtick.sh into
# ~/install/gcc-trunk-backtick. Every installed program carries the
# -17-backtick suffix, so nothing collides with a vanilla ~/install/gcc-17.
# Without -fbacktick this compiler behaves exactly like upstream trunk, so
# the flag is added here rather than in gcc-flags.cmake.

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/gcc-flags.cmake")

set(BACKTICKS_GCC_PREFIX
    "$ENV{HOME}/install/gcc-trunk-backtick"
    CACHE PATH
    "Install prefix of the trunk backtick gcc"
)

set(CMAKE_C_COMPILER "${BACKTICKS_GCC_PREFIX}/bin/gcc-17-backtick")
set(CMAKE_CXX_COMPILER "${BACKTICKS_GCC_PREFIX}/bin/g++-17-backtick")
set(GCOV_EXECUTABLE
    "${BACKTICKS_GCC_PREFIX}/bin/gcov-17-backtick"
    CACHE STRING
    "GCOV executable"
    FORCE
)

# gcc-flags.cmake FORCE-sets CMAKE_CXX_FLAGS on every configure, so this
# append runs exactly once per run and cannot accumulate duplicates.
set(CMAKE_CXX_FLAGS
    "${CMAKE_CXX_FLAGS} -fbacktick"
    CACHE STRING
    "CXX_FLAGS"
    FORCE
)

# This prefix ships its own libstdc++ (`make install`, not just
# `install-gcc`); link against it rather than whatever is on the system
# default search path.
set(CMAKE_EXE_LINKER_FLAGS
    "-Wl,-rpath,${BACKTICKS_GCC_PREFIX}/lib64"
    CACHE STRING
    "CMAKE_EXE_LINKER_FLAGS"
    FORCE
)

set(CMAKE_CXX_FLAGS_ASAN
    "${CMAKE_CXX_FLAGS_ASAN} -Wno-maybe-uninitialized"
    CACHE STRING
    "C++ ASAN Flags"
    FORCE
)
