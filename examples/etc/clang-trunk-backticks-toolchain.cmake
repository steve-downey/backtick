# etc/clang-trunk-backticks-toolchain.cmake                         -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# The infix-backtick prototype built on LLVM trunk (branch backtick-trunk),
# installed by ops/build/configure-clang-trunk-backtick.sh into
# ~/install/clang-trunk-backtick. Same feature diff as the release/23.x
# track; see etc/clang-23-backticks-toolchain.cmake.

include_guard(GLOBAL)

set(BACKTICKS_CLANG_TRUNK_PREFIX
    "$ENV{HOME}/install/clang-trunk-backtick"
    CACHE PATH
    "Install prefix of the trunk backtick clang"
)

set(CMAKE_C_COMPILER "${BACKTICKS_CLANG_TRUNK_PREFIX}/bin/clang")
set(CMAKE_CXX_COMPILER "${BACKTICKS_CLANG_TRUNK_PREFIX}/bin/clang++")
set(GCOV_EXECUTABLE
    "${BACKTICKS_CLANG_TRUNK_PREFIX}/bin/llvm-cov gcov"
    CACHE STRING
    "GCOV executable"
    FORCE
)

# See etc/clang-23-backticks-toolchain.cmake: a stock clang-scan-deps
# rejects -fbacktick.
set(CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS
    "${BACKTICKS_CLANG_TRUNK_PREFIX}/bin/clang-scan-deps"
    CACHE FILEPATH
    "Clang module dependency scanner"
    FORCE
)

include("${CMAKE_CURRENT_LIST_DIR}/clang-flags.cmake")

set(CMAKE_CXX_FLAGS
    "${CMAKE_CXX_FLAGS} -fbacktick"
    CACHE STRING
    "CXX_FLAGS"
    FORCE
)
