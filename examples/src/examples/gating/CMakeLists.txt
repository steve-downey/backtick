# src/examples/gating/CMakeLists.txt                                -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

add_test(
    NAME backtick.is-gated
    COMMAND
        ${CMAKE_COMMAND} -DCOMPILER=${CMAKE_CXX_COMPILER}
        "-DFLAGS=${CMAKE_CXX_FLAGS}"
        -DSOURCE=${CMAKE_CURRENT_SOURCE_DIR}/gated.cpp -P
        ${PROJECT_SOURCE_DIR}/cmake/require-gated.cmake
)
