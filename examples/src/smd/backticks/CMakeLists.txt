include(GNUInstallDirs)

target_sources(
    example.backticks
    PUBLIC FILE_SET backticks_backticks_headers TYPE HEADERS FILES backticks.hpp
    PRIVATE backticks.cpp
)

## Tests
if(BACKTICKS_ENABLE_TESTING AND NOT Catch2_FOUND)
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

if(BACKTICKS_ENABLE_TESTING)
    add_executable(backticks_test)

    target_sources(backticks_test PRIVATE backticks.test.cpp)

    target_link_libraries(backticks_test example.backticks)
    target_link_libraries(backticks_test Catch2::Catch2WithMain)

    include(Catch)
    catch_discover_tests(backticks_test)
endif()
