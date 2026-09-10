# etc/clang-23-backticks-toolchain.cmake                            -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# The infix-backtick prototype built on the LLVM release/23.x branch
# (branch backtick-23), installed by
# ops/build/configure-clang23-backtick.sh into ~/install/clang-23-backtick.
# Without -fbacktick this compiler behaves exactly like upstream clang-23,
# so the flag is added here rather than in clang-flags.cmake.

include_guard(GLOBAL)

set(BACKTICKS_CLANG_23_PREFIX
    "$ENV{HOME}/install/clang-23-backtick"
    CACHE PATH
    "Install prefix of the release/23.x backtick clang"
)

set(CMAKE_C_COMPILER "${BACKTICKS_CLANG_23_PREFIX}/bin/clang")
set(CMAKE_CXX_COMPILER "${BACKTICKS_CLANG_23_PREFIX}/bin/clang++")
set(GCOV_EXECUTABLE
    "${BACKTICKS_CLANG_23_PREFIX}/bin/llvm-cov gcov"
    CACHE STRING
    "GCOV executable"
    FORCE
)

# CMake's C++20 module scanning otherwise picks up whichever
# clang-scan-deps-23 is on PATH, and a stock one rejects -fbacktick with
# "unknown argument". Use the one built alongside this compiler.
set(CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS
    "${BACKTICKS_CLANG_23_PREFIX}/bin/clang-scan-deps"
    CACHE FILEPATH
    "Clang module dependency scanner"
    FORCE
)

include("${CMAKE_CURRENT_LIST_DIR}/clang-flags.cmake")

# clang-flags.cmake FORCE-sets CMAKE_CXX_FLAGS on every configure, so this
# append runs exactly once per run and cannot accumulate duplicates.
set(CMAKE_CXX_FLAGS
    "${CMAKE_CXX_FLAGS} -fbacktick"
    CACHE STRING
    "CXX_FLAGS"
    FORCE
)
