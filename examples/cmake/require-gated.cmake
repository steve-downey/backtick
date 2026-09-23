# cmake/require-gated.cmake                                         -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Script mode. Requires that SOURCE compiles with the prototype's flag and
# fails to compile without it.
#
# Both prototypes gate every new behaviour behind -fbacktick, so that a default
# build is bit-for-bit upstream. This is that invariant checked from outside the
# compiler: if someone ever lets the parse leak into a stock configuration, the
# second half of this test goes green when it should be red.
#
# Expected variables: COMPILER, FLAGS, SOURCE

foreach(var COMPILER FLAGS SOURCE)
    if(NOT DEFINED ${var})
        message(FATAL_ERROR "require-gated: -D${var}= is required")
    endif()
endforeach()

separate_arguments(flag_list NATIVE_COMMAND "${FLAGS}")

execute_process(
    COMMAND ${COMPILER} ${flag_list} -fsyntax-only "${SOURCE}"
    OUTPUT_QUIET
    ERROR_VARIABLE err
    RESULT_VARIABLE rc
)
if(NOT rc EQUAL 0)
    message(
        FATAL_ERROR
        "require-gated: ${SOURCE} did not compile with the feature enabled\n${err}"
    )
endif()

execute_process(
    COMMAND ${COMPILER} ${flag_list} -fno-backtick -fsyntax-only "${SOURCE}"
    OUTPUT_QUIET
    ERROR_VARIABLE err
    RESULT_VARIABLE rc
)
if(rc EQUAL 0)
    message(
        FATAL_ERROR
        "require-gated: ${SOURCE} still compiled under -fno-backtick.\n"
        "The infix backtick is supposed to be unavailable without the flag."
    )
endif()
