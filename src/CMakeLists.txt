cmake_minimum_required(VERSION 3.25)
if(APPLE)
    add_executable(${PROJECT_NAME} MACOSX_BUNDLE)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE_BUNDLE_NAME "${GAME_WINDOW_TITLE}"
        MACOSX_BUNDLE_GUI_IDENTIFIER "${GAME_BUNDLE_IDENTIFIER}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    )
else()
    add_executable(${PROJECT_NAME})
endif()

target_sources(${PROJECT_NAME} PRIVATE
    main.c
    game.c
    game.h
)
target_link_libraries(${PROJECT_NAME} PRIVATE raylib)
if(GAME_ENABLE_IMGUI)
    target_link_libraries(${PROJECT_NAME} PRIVATE rayplate_imgui)
endif()

set(game_assets_dir "${CMAKE_SOURCE_DIR}/assets")
if(EXISTS "${game_assets_dir}")
    if(EMSCRIPTEN OR PLATFORM STREQUAL "Web")
        set(game_runtime_asset_dir "assets")
        target_link_options(${PROJECT_NAME} PRIVATE
            "--preload-file" "${game_assets_dir}@/assets"
        )
    elseif(APPLE)
        set(game_runtime_asset_dir "../Resources/assets")
        set(game_asset_output_dir "$<TARGET_BUNDLE_CONTENT_DIR:${PROJECT_NAME}>/Resources/assets")
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E remove_directory
                    "${game_asset_output_dir}"
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                    "${game_assets_dir}"
                    "${game_asset_output_dir}"
            COMMENT "Copying game assets into the app bundle"
            VERBATIM
        )
    else()
        set(game_runtime_asset_dir "assets")
        set(game_asset_output_dir "$<TARGET_FILE_DIR:${PROJECT_NAME}>/assets")
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E remove_directory
                    "${game_asset_output_dir}"
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                    "${game_assets_dir}"
                    "${game_asset_output_dir}"
            COMMENT "Copying game assets"
            VERBATIM
        )
    endif()
else()
    set(game_runtime_asset_dir "assets")
endif()

find_package(Python3 COMPONENTS Interpreter REQUIRED)
set(game_assets_generated_dir "${CMAKE_BINARY_DIR}/generated/assets")
set(game_assets_header "${game_assets_generated_dir}/game_assets.h")
set(game_assets_source "${game_assets_generated_dir}/game_assets.c")
set(game_assets_manifest "${game_assets_generated_dir}/game_assets.manifest")
file(GLOB_RECURSE game_asset_files CONFIGURE_DEPENDS "${game_assets_dir}/*")
list(SORT game_asset_files)

set(game_assets_manifest_content "")
foreach(game_asset_file IN LISTS game_asset_files)
    file(RELATIVE_PATH game_asset_relative_path "${game_assets_dir}" "${game_asset_file}")
    string(APPEND game_assets_manifest_content "${game_asset_relative_path}\n")
endforeach()
file(WRITE "${game_assets_manifest}" "${game_assets_manifest_content}")

add_custom_command(
    OUTPUT "${game_assets_header}" "${game_assets_source}"
    COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_SOURCE_DIR}/scripts/generate_game_assets.py"
            --assets-dir "${game_assets_dir}"
            --header "${game_assets_header}"
            --source "${game_assets_source}"
            --include-name "game_assets.h"
    DEPENDS
            "${CMAKE_SOURCE_DIR}/scripts/generate_game_assets.py"
            "${game_assets_manifest}"
            ${game_asset_files}
    COMMENT "Generating game asset catalog"
    VERBATIM
)
add_custom_target(generate_game_assets
    DEPENDS "${game_assets_header}" "${game_assets_source}"
)
add_dependencies(${PROJECT_NAME} generate_game_assets)
target_sources(${PROJECT_NAME} PRIVATE "${game_assets_source}")
target_include_directories(${PROJECT_NAME} PRIVATE "${game_assets_generated_dir}")

# Escape the cache value as a C string literal before passing it through the
# compiler command line. This keeps CMake as the single source of truth for the
# application and macOS bundle title.
set(game_window_title_c "${GAME_WINDOW_TITLE}")
string(REPLACE "\\" "\\\\" game_window_title_c "${game_window_title_c}")
string(REPLACE "\"" "\\\"" game_window_title_c "${game_window_title_c}")
set(game_runtime_asset_dir_c "${game_runtime_asset_dir}")
string(REPLACE "\\" "\\\\" game_runtime_asset_dir_c "${game_runtime_asset_dir_c}")
string(REPLACE "\"" "\\\"" game_runtime_asset_dir_c "${game_runtime_asset_dir_c}")
target_compile_definitions(${PROJECT_NAME} PRIVATE
    GAME_WINDOW_TITLE="${game_window_title_c}"
    GAME_RUNTIME_ASSET_DIR="${game_runtime_asset_dir_c}"
)

# Keep strict warnings scoped to application code so third-party dependencies do
# not break a build when a compiler adds a new diagnostic.
if(MSVC)
    target_compile_options(${PROJECT_NAME} PRIVATE /W4)
    if(GAME_WARNINGS_AS_ERRORS)
        target_compile_options(${PROJECT_NAME} PRIVATE /WX)
    endif()
elseif(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra -Wpedantic)
    if(GAME_WARNINGS_AS_ERRORS)
        target_compile_options(${PROJECT_NAME} PRIVATE -Werror)
    endif()
endif()

if(GAME_ENABLE_SANITIZERS)
    if(MSVC)
        target_compile_options(${PROJECT_NAME} PRIVATE /fsanitize=address)
    elseif(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${PROJECT_NAME} PRIVATE
            -fsanitize=address,undefined -fno-omit-frame-pointer)
        target_link_options(${PROJECT_NAME} PRIVATE -fsanitize=address,undefined)
    else()
        message(FATAL_ERROR
            "GAME_ENABLE_SANITIZERS is unsupported by ${CMAKE_C_COMPILER_ID}")
    endif()
endif()

if(GAME_ANGLE_ENABLED)
    target_sources(${PROJECT_NAME} PRIVATE angle_cfg.c angle_cfg.h)
    game_configure_angle_application(${PROJECT_NAME})
endif()

# raylib's static library requires libm after it in the Linux link order.
if(UNIX AND NOT APPLE AND NOT EMSCRIPTEN)
    target_link_libraries(${PROJECT_NAME} PRIVATE m)
endif()

if(TARGET raylib_alias)
    add_dependencies(${PROJECT_NAME} generate_raylib_alias)
    target_link_libraries(${PROJECT_NAME} PRIVATE raylib_alias)
endif()

if(PLATFORM STREQUAL "Web")
    set_target_properties(${PROJECT_NAME} PROPERTIES SUFFIX ".html")
endif()

if(BUILD_TESTING AND GAME_ANGLE_ENABLED)
    add_test(NAME graphics_api_help COMMAND ${PROJECT_NAME} --help)
    add_test(NAME graphics_api_invalid COMMAND ${PROJECT_NAME} --graphics-api=invalid)
    set_tests_properties(graphics_api_invalid PROPERTIES WILL_FAIL TRUE)
endif()
