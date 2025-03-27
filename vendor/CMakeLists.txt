cmake_minimum_required(VERSION 3.5)

# Create the vendor INTERFACE library
add_library(vendor INTERFACE)

# Setting up raylib
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
add_subdirectory(raylib EXCLUDE_FROM_ALL)

# Paths
set(RAYLIB_HEADER_PATH "${CMAKE_CURRENT_SOURCE_DIR}/raylib/src/raylib.h")
set(RL_ALIAS_HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}/aliased")
set(RL_ALIAS_HEADER_PATH "${RL_ALIAS_HEADER_DIR}/rl_alias.h")

# Determine alias script path if aliasing is enabled
message("RL_ALIAS_MODE=" ${RL_ALIAS_MODE})
message("RL_ALIAS_PREFIX=" ${RL_ALIAS_PREFIX})
if (NOT RL_ALIAS_MODE STREQUAL "")
    if (RL_ALIAS_MODE STREQUAL "INLINE")
        set(ALIAS_SCRIPT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/rl_alias_inline.py")
    elseif(RL_ALIAS_MODE STREQUAL "DEFINE")
        set(ALIAS_SCRIPT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/rl_alias_define.py")
    else()
        message(FATAL_ERROR ${RL_ALIAS_MODE} " mode is not supported.")
    endif()

    find_package(Python REQUIRED)
    file(MAKE_DIRECTORY ${RL_ALIAS_HEADER_DIR})

    add_custom_command(
        OUTPUT ${RL_ALIAS_HEADER_PATH}
        COMMAND ${Python_EXECUTABLE} ${ALIAS_SCRIPT_PATH} ${RAYLIB_HEADER_PATH} ${RL_ALIAS_HEADER_PATH} ${RL_ALIAS_PREFIX}
        DEPENDS ${RAYLIB_HEADER_PATH} ${ALIAS_SCRIPT_PATH}
        COMMENT "Generating rl_alias.h"
        VERBATIM
    )

    add_custom_target(generate_raylib_alias DEPENDS ${RL_ALIAS_HEADER_PATH})

    add_library(raylib_alias INTERFACE)
    add_dependencies(raylib_alias generate_raylib_alias)
    target_include_directories(raylib_alias INTERFACE ${RL_ALIAS_HEADER_DIR})

    add_dependencies(vendor generate_raylib_alias)
    target_link_libraries(vendor INTERFACE raylib raylib_alias) # link raylib + alias
else()
    target_link_libraries(vendor INTERFACE raylib) # only link raylib
endif()