# src/smd/infix/CMakeLists.txt                                      -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

include(GNUInstallDirs)

target_sources(
    backtick-examples.infix
    INTERFACE FILE_SET infix_infix_headers TYPE HEADERS FILES pipe.hpp
)

## Tests
if(INFIX_ENABLE_TESTING AND NOT Catch2_FOUND)
    find_package(Catch2 3 QUIET)
    if(Catch2_FOUND)
        include(Catch)
    else()
        message(
            WARNING
            "
No provider for Catch2. Unable to build tests.
Consider using CMAKE_PROJECT_TOP_LEVEL_INCLUDES=./cmake/use-fetch-content.cmake as documented in the README.md
"
        )
    endif()
endif()

if(INFIX_ENABLE_TESTING)
    add_executable(pipe_test)

    target_sources(pipe_test PRIVATE pipe.test.cpp)

    target_link_libraries(pipe_test backtick-examples.infix)
    target_link_libraries(pipe_test Catch2::Catch2WithMain)

    include(Catch)
    catch_discover_tests(pipe_test)
endif()
