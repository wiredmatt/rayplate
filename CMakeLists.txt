cmake_minimum_required(VERSION 3.25)
project(my_game)
set(CMAKE_C_STANDARD 99)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

# Download and configure raylib.
include(FetchContent)

set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
    raylib
    URL https://github.com/raysan5/raylib/archive/refs/tags/6.0.tar.gz
    URL_HASH SHA256=2b3ee1e2120c7a0796b33062c7e9a694dd8a8caa56a96319ac8c8ecf54a90d0b
    DOWNLOAD_EXTRACT_TIMESTAMP OFF
)
FetchContent_MakeAvailable(raylib)

# Generate optional prefixed aliases for the raylib API.
set(RAYLIB_HEADER_PATH "${raylib_SOURCE_DIR}/src/raylib.h")
set(RL_ALIAS_HEADER_DIR "${CMAKE_BINARY_DIR}/aliased")
set(RL_ALIAS_HEADER_PATH "${RL_ALIAS_HEADER_DIR}/rl_alias.h")

message("RL_ALIAS_MODE=" ${RL_ALIAS_MODE})
message("RL_ALIAS_PREFIX=" ${RL_ALIAS_PREFIX})

if(NOT RL_ALIAS_MODE STREQUAL "")
    if(NOT RL_ALIAS_MODE STREQUAL "INLINE" AND NOT RL_ALIAS_MODE STREQUAL "DEFINE")
        message(FATAL_ERROR "${RL_ALIAS_MODE} mode is not supported.")
    endif()

    set(ALIAS_SCRIPT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/generate_rl_alias.cmake")
    file(MAKE_DIRECTORY "${RL_ALIAS_HEADER_DIR}")

    add_custom_command(
        OUTPUT "${RL_ALIAS_HEADER_PATH}"
        COMMAND ${CMAKE_COMMAND}
            -DRAYLIB_HEADER_PATH=${RAYLIB_HEADER_PATH}
            -DRL_ALIAS_HEADER_PATH=${RL_ALIAS_HEADER_PATH}
            -DRL_ALIAS_MODE=${RL_ALIAS_MODE}
            -DRL_ALIAS_PREFIX=${RL_ALIAS_PREFIX}
            -P ${ALIAS_SCRIPT_PATH}
        DEPENDS "${RAYLIB_HEADER_PATH}" "${ALIAS_SCRIPT_PATH}"
        COMMENT "Generating rl_alias.h"
        VERBATIM
    )

    add_custom_target(generate_raylib_alias DEPENDS "${RL_ALIAS_HEADER_PATH}")
    add_library(raylib_alias INTERFACE)
    add_dependencies(raylib_alias generate_raylib_alias)
    target_include_directories(raylib_alias INTERFACE "${RL_ALIAS_HEADER_DIR}")
endif()

add_subdirectory(src)
