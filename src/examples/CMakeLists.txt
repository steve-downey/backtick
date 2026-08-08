include(GNUInstallDirs)

add_executable(hello)

# Add example source file.
target_sources(hello PRIVATE hello.cpp)

# Link example with the library.
target_link_libraries(hello PRIVATE backtick-examples.infix)

install(
    TARGETS hello
    COMPONENT backtick-examples.infix.examples
    DESTINATION ${CMAKE_INSTALL_BINDIR}
    EXCLUDE_FROM_ALL
)
