# cmake/compare-golden.cmake                                        -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Script mode. Runs one program and requires its output to match the
# checked-in golden.
#
# Expected variables: NAME, BINARY, EXPECTED, WORKDIR

foreach(var NAME BINARY EXPECTED WORKDIR)
    if(NOT DEFINED ${var})
        message(FATAL_ERROR "compare-golden: -D${var}= is required")
    endif()
endforeach()

set(out "${WORKDIR}/${NAME}.out")

execute_process(
    COMMAND "${BINARY}"
    OUTPUT_FILE "${out}"
    ERROR_VARIABLE err
    RESULT_VARIABLE rc
)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "compare-golden: ${NAME} exited ${rc}\n${err}")
endif()

if(NOT EXISTS "${EXPECTED}")
    message(
        FATAL_ERROR
        "compare-golden: ${NAME}: no golden output at ${EXPECTED}.\n"
        "If the output below is right, save it there:\n"
        "  cp ${out} ${EXPECTED}"
    )
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E compare_files "${out}" "${EXPECTED}"
    RESULT_VARIABLE rc
)
if(NOT rc EQUAL 0)
    file(READ "${EXPECTED}" want)
    file(READ "${out}" got)
    message(
        FATAL_ERROR
        "compare-golden: ${NAME}: output does not match the golden.\n"
        "--- expected (${EXPECTED}) ---\n${want}"
        "--- actual ---\n${got}"
    )
endif()
