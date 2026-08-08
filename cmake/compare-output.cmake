# cmake/compare-output.cmake                                        -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Script mode. Runs the two halves of a paired example and requires that they
# agree with each other and with the checked-in golden output.
#
# Two programs printing the same thing is not by itself evidence -- they could
# be wrong together. The golden file is what pins the behaviour; the pairwise
# comparison is what pins the claim that the rewrite changed only spelling.
#
# Expected variables: NAME, PIPE, BACKTICK, EXPECTED, WORKDIR

foreach(var NAME PIPE BACKTICK EXPECTED WORKDIR)
    if(NOT DEFINED ${var})
        message(FATAL_ERROR "compare-output: -D${var}= is required")
    endif()
endforeach()

function(run_half variant binary out_var)
    set(out "${WORKDIR}/${NAME}.${variant}.out")
    execute_process(
        COMMAND "${binary}"
        OUTPUT_FILE "${out}"
        ERROR_VARIABLE err
        RESULT_VARIABLE rc
    )
    if(NOT rc EQUAL 0)
        message(
            FATAL_ERROR
            "compare-output: ${NAME}.${variant} exited ${rc}\n${err}"
        )
    endif()
    set(${out_var} "${out}" PARENT_SCOPE)
endfunction()

run_half(pipe "${PIPE}" pipe_out)
run_half(backtick "${BACKTICK}" backtick_out)

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E compare_files "${pipe_out}" "${backtick_out}"
    RESULT_VARIABLE rc
)
if(NOT rc EQUAL 0)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E compare_files "${pipe_out}" "${backtick_out}"
        COMMAND_ECHO NONE
    )
    message(
        FATAL_ERROR
        "compare-output: ${NAME}: the two spellings disagree.\n"
        "  pipe:     ${pipe_out}\n"
        "  backtick: ${backtick_out}"
    )
endif()

if(NOT EXISTS "${EXPECTED}")
    message(
        FATAL_ERROR
        "compare-output: ${NAME}: no golden output at ${EXPECTED}.\n"
        "Both halves agree; if that output is right, save it there:\n"
        "  cp ${pipe_out} ${EXPECTED}"
    )
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E compare_files "${pipe_out}" "${EXPECTED}"
    RESULT_VARIABLE rc
)
if(NOT rc EQUAL 0)
    file(READ "${EXPECTED}" want)
    file(READ "${pipe_out}" got)
    message(
        FATAL_ERROR
        "compare-output: ${NAME}: both halves agree but disagree with the golden output.\n"
        "--- expected (${EXPECTED}) ---\n${want}"
        "--- actual ---\n${got}"
    )
endif()
