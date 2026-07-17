cmake_minimum_required(VERSION 3.25)

# Project identity defaults used by CMake and generated application metadata.
set(GAME_BIN_NAME "my_game" CACHE STRING "Executable and build target name")
set(GAME_WINDOW_TITLE "My Game" CACHE STRING "Human-readable application name")
set(GAME_VERSION "0.1.0" CACHE STRING "Application version")
set(GAME_BUNDLE_IDENTIFIER "io.github.example.my-game" CACHE STRING
    "Reverse-DNS application bundle identifier")

project(${GAME_BIN_NAME} VERSION ${GAME_VERSION} LANGUAGES C CXX)
include(CTest)
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

option(GAME_WARNINGS_AS_ERRORS
    "Treat warnings in Rayplate application code as errors" OFF)
option(GAME_ENABLE_SANITIZERS
    "Enable AddressSanitizer and, where supported, UndefinedBehaviorSanitizer" OFF)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(RayplateAngle)
game_prepare_angle()

set(RL_ALIAS_MODE "INLINE" CACHE STRING "Alias implementation: INLINE, DEFINE, or empty to disable")
set_property(CACHE RL_ALIAS_MODE PROPERTY STRINGS "INLINE" "DEFINE" "")
set(RAYLIB_ALIAS_PREFIX "RLIB_" CACHE STRING "Prefix for raylib API aliases")
set(RLGL_ALIAS_PREFIX "RLGL_" CACHE STRING "Prefix for rlgl API aliases")
set(RLIMGUI_ALIAS_PREFIX "RGUI_" CACHE STRING "Prefix for rlImGui API aliases")
set(CIMGUI_ALIAS_PREFIX "IMGUI_" CACHE STRING "Prefix for cimgui API aliases")

# Download and configure raylib, cimgui, and the raylib Dear ImGui backend.
include(FetchContent)

set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
    raylib
    URL https://github.com/raysan5/raylib/archive/refs/tags/6.0.tar.gz
    URL_HASH SHA256=2b3ee1e2120c7a0796b33062c7e9a694dd8a8caa56a96319ac8c8ecf54a90d0b
    DOWNLOAD_EXTRACT_TIMESTAMP OFF
)

# cimgui's generated wrapper and its Dear ImGui submodule must stay at matching
# revisions. The git commit pins both; a release archive would omit the
# submodule. rlImGui's Raylib_6_0 tag supports Dear ImGui's 1.92 texture API.
set(IMGUI_STATIC "yes" CACHE STRING "Build cimgui as a static library" FORCE)
set(CIMGUI_TEST "no" CACHE STRING "Disable cimgui's standalone test" FORCE)
FetchContent_Declare(
    cimgui
    GIT_REPOSITORY https://github.com/cimgui/cimgui.git
    GIT_TAG d298666861ebf00dcfeb2407409931c04e47e33c
    GIT_SHALLOW FALSE
    GIT_PROGRESS TRUE
)
FetchContent_Declare(
    rlimgui
    URL https://github.com/raylib-extras/rlImGui/archive/refs/tags/Raylib_6_0.tar.gz
    URL_HASH SHA256=2d2385f42595ca1f5fd10434c1d34b4392994ba28105454ab88bc808a9bafd33
    DOWNLOAD_EXTRACT_TIMESTAMP OFF
)
FetchContent_MakeAvailable(raylib cimgui rlimgui)

# cimgui is linked into the game, so neither its implementation nor consumers
# should use DLL import/export annotations. Its generated C declarations expose
# complete structs and enums only when this definition is enabled.
target_compile_definitions(cimgui PRIVATE CIMGUI_NO_EXPORT)
target_compile_definitions(cimgui INTERFACE
    CIMGUI_NO_EXPORT
    CIMGUI_DEFINE_ENUMS_AND_STRUCTS
)
set_property(TARGET cimgui PROPERTY INTERFACE_SYSTEM_INCLUDE_DIRECTORIES
    "${cimgui_SOURCE_DIR}"
    "${cimgui_SOURCE_DIR}/imgui"
)

add_library(rayplate_imgui STATIC "${rlimgui_SOURCE_DIR}/rlImGui.cpp")
target_include_directories(rayplate_imgui PUBLIC "${rlimgui_SOURCE_DIR}")
target_link_libraries(rayplate_imgui PUBLIC cimgui raylib)

if(EMSCRIPTEN)
    set_target_properties(raylib PROPERTIES
        C_STANDARD 99
        C_STANDARD_REQUIRED ON
        C_EXTENSIONS ON
    )
endif()

game_configure_angle_raylib(raylib)

# Generate optional prefixed aliases for the raylib, rlgl, rlImGui, and cimgui APIs.
set(RAYLIB_HEADER_PATH "${raylib_SOURCE_DIR}/src/raylib.h")
set(RLGL_HEADER_PATH "${raylib_SOURCE_DIR}/src/rlgl.h")
set(RLIMGUI_HEADER_PATH "${rlimgui_SOURCE_DIR}/rlImGui.h")
set(CIMGUI_HEADER_PATH "${cimgui_SOURCE_DIR}/cimgui.h")
set(RL_ALIAS_HEADER_DIR "${CMAKE_BINARY_DIR}/aliased")
set(RL_ALIAS_HEADER_PATH "${RL_ALIAS_HEADER_DIR}/rl_alias.h")

message("RL_ALIAS_MODE=" ${RL_ALIAS_MODE})
message("RAYLIB_ALIAS_PREFIX=" ${RAYLIB_ALIAS_PREFIX})
message("RLGL_ALIAS_PREFIX=" ${RLGL_ALIAS_PREFIX})
message("RLIMGUI_ALIAS_PREFIX=" ${RLIMGUI_ALIAS_PREFIX})
message("CIMGUI_ALIAS_PREFIX=" ${CIMGUI_ALIAS_PREFIX})

if(NOT RL_ALIAS_MODE STREQUAL "")
    if(NOT RL_ALIAS_MODE STREQUAL "INLINE" AND NOT RL_ALIAS_MODE STREQUAL "DEFINE")
        message(FATAL_ERROR "${RL_ALIAS_MODE} mode is not supported.")
    endif()

    set(ALIAS_SCRIPT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateAliases.cmake")
    file(MAKE_DIRECTORY "${RL_ALIAS_HEADER_DIR}")

    add_custom_command(
        OUTPUT "${RL_ALIAS_HEADER_PATH}"
        COMMAND ${CMAKE_COMMAND}
        -DRAYLIB_HEADER_PATH=${RAYLIB_HEADER_PATH}
        -DRLGL_HEADER_PATH=${RLGL_HEADER_PATH}
        -DRLIMGUI_HEADER_PATH=${RLIMGUI_HEADER_PATH}
        -DCIMGUI_HEADER_PATH=${CIMGUI_HEADER_PATH}
        -DRL_ALIAS_HEADER_PATH=${RL_ALIAS_HEADER_PATH}
        -DRL_ALIAS_MODE=${RL_ALIAS_MODE}
        -DRAYLIB_ALIAS_PREFIX=${RAYLIB_ALIAS_PREFIX}
        -DRLGL_ALIAS_PREFIX=${RLGL_ALIAS_PREFIX}
        -DRLIMGUI_ALIAS_PREFIX=${RLIMGUI_ALIAS_PREFIX}
        -DCIMGUI_ALIAS_PREFIX=${CIMGUI_ALIAS_PREFIX}
        -P ${ALIAS_SCRIPT_PATH}
        DEPENDS
            "${RAYLIB_HEADER_PATH}"
            "${RLGL_HEADER_PATH}"
            "${RLIMGUI_HEADER_PATH}"
            "${CIMGUI_HEADER_PATH}"
            "${ALIAS_SCRIPT_PATH}"
        COMMENT "Generating rl_alias.h"
        VERBATIM
    )

    add_custom_target(generate_raylib_alias DEPENDS "${RL_ALIAS_HEADER_PATH}")
    add_library(raylib_alias INTERFACE)
    add_dependencies(raylib_alias generate_raylib_alias)
    target_include_directories(raylib_alias INTERFACE "${RL_ALIAS_HEADER_DIR}")
endif()

add_subdirectory(src)
