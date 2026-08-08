# src/examples/senders/CMakeLists.txt                               -*-cmake-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

# The lockfile provider in infra/cmake/use-fetch-content.cmake answers this
# when it is installed. Under vcpkg it is not, and beman_execution is not a
# vcpkg port, so fall back to FetchContent at the same pin.
#
# To build against a local checkout instead:
#   -DFETCHCONTENT_SOURCE_DIR_BEMAN_EXECUTION=$HOME/src/Execution26
find_package(beman_execution QUIET)

if(NOT TARGET beman::execution)
    # beman.execution turns its C++20 module build on by default for clang 19+,
    # and a BMI built there with CXX_EXTENSIONS OFF cannot be consumed by these
    # examples, which compile at -std=gnu++2x. The examples include headers
    # rather than importing, so build it as headers.
    set(BEMAN_USE_MODULES OFF)

    include(FetchContent)
    FetchContent_Declare(
        beman_execution
        GIT_REPOSITORY https://github.com/bemanproject/execution.git
        GIT_TAG 64311b29ac5f3ed407847eca4da0e521a9822898
        EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(beman_execution)
endif()

if(NOT TARGET beman::execution)
    message(
        WARNING
        "No provider for beman_execution. Skipping the sender examples."
    )
    return()
endif()

add_paired_example(chain LIBS beman::execution)
add_paired_example(hop LIBS beman::execution)
add_paired_example(scan LIBS beman::execution)
