cmake_minimum_required(VERSION 4.0)

project(raylib_template)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

add_subdirectory(vendor)
add_subdirectory(src)