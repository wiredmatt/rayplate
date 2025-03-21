cmake_minimum_required(VERSION 3.5)
set(CMAKE_C_STANDARD 99)

project(my_game)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

add_subdirectory(vendor)
add_subdirectory(src)