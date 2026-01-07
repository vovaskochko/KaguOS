# KaguOS Tools - Bare Metal Edition
# CMake build configuration
cmake_minimum_required(VERSION 3.16)
project(KaguOS VERSION 1.0.0 LANGUAGES CXX)

# C++20 standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Compiler warnings
if(NOT MSVC)
    add_compile_options(-Wall -Wextra -Wpedantic)
else()
    add_compile_options(-Wall)
endif()

# Build type defaults to Release
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Output directories - executables in build/bin
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Add subdirectories
add_subdirectory(libkagu)
add_subdirectory(kagu_boot)

# Custom target to copy executables to project root
add_custom_target(install_to_root ALL
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:kagu_boot> ${CMAKE_SOURCE_DIR}/../kagu_boot${CMAKE_EXECUTABLE_SUFFIX}
    DEPENDS kagu_boot
    COMMENT "Copying executables to project root"
)

# Info target
add_custom_target(info
    COMMAND ${CMAKE_COMMAND} -E echo "=== KaguOS Tools - Bare Metal Edition ==="
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Components:"
    COMMAND ${CMAKE_COMMAND} -E echo "  kagu_boot  - KaguOS emulator (bare metal mode)"
    COMMAND ${CMAKE_COMMAND} -E echo "  libkagu    - Shared headers (interface library)"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Build:"
    COMMAND ${CMAKE_COMMAND} -E echo "  mkdir build && cd build && cmake .. && make"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "After build, executables are copied to project root."
    VERBATIM
)
