# cmake/add_paired_example.cmake                                    -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

include_guard(GLOBAL)
include(GNUInstallDirs)

# add_paired_example(<name> [LIBS <lib>...])
# ==========================================
#
# Every example in this project ships twice, from two sources that differ only
# in how they spell their calls:
#
#   <name>.pipe.cpp      the idiom as it is written today, with operator|
#   <name>.backtick.cpp  the same pipeline with the backtick operator
#
# Both are compiled by the same compiler at the same settings, and a test
# requires their output to be identical -- and to match <name>.expected.
#
# The .pipe half is compiled with -fno-backtick, so it is not merely "code that
# happens not to use the feature" but code proven to compile with the feature
# switched off. That is the same invariant the prototypes assert in their own
# regression suites: a build without the flag behaves exactly as upstream.
function(add_paired_example name)
    cmake_parse_arguments(PE "" "" "LIBS" ${ARGN})

    foreach(variant IN ITEMS pipe backtick)
        set(tgt ${name}.${variant})
        add_executable(${tgt})
        target_sources(${tgt} PRIVATE ${name}.${variant}.cpp)
        target_link_libraries(
            ${tgt}
            PRIVATE backtick-examples.infix ${PE_LIBS}
        )
        install(
            TARGETS ${tgt}
            COMPONENT backtick-examples.infix.examples
            DESTINATION ${CMAKE_INSTALL_BINDIR}
            EXCLUDE_FROM_ALL
        )
    endforeach()

    target_compile_options(${name}.pipe PRIVATE -fno-backtick)

    add_test(
        NAME ${name}.equivalent
        COMMAND
            ${CMAKE_COMMAND} -DNAME=${name} -DPIPE=$<TARGET_FILE:${name}.pipe>
            -DBACKTICK=$<TARGET_FILE:${name}.backtick>
            -DEXPECTED=${CMAKE_CURRENT_SOURCE_DIR}/${name}.expected
            -DWORKDIR=${CMAKE_CURRENT_BINARY_DIR} -P
            ${PROJECT_SOURCE_DIR}/cmake/compare-output.cmake
    )
endfunction()
