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
