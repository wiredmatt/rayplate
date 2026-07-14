cmake_minimum_required(VERSION 3.25)
if(APPLE)
    add_executable(${PROJECT_NAME} MACOSX_BUNDLE)
    set(RAYPLATE_MACOS_BUNDLE_IDENTIFIER "io.github.wiredmatt.rayplate" CACHE STRING
        "Bundle identifier used for the macOS application")
    set(RAYPLATE_MACOS_BUNDLE_VERSION "1.0.0" CACHE STRING
        "Version written to the macOS application bundle")
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE_BUNDLE_NAME "${PROJECT_NAME}"
        MACOSX_BUNDLE_GUI_IDENTIFIER "${RAYPLATE_MACOS_BUNDLE_IDENTIFIER}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${RAYPLATE_MACOS_BUNDLE_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${RAYPLATE_MACOS_BUNDLE_VERSION}"
    )
else()
    add_executable(${PROJECT_NAME})
endif()

target_sources(${PROJECT_NAME} PRIVATE main.c)
target_link_libraries(${PROJECT_NAME} PRIVATE raylib)

if(RAYPLATE_ANGLE_ENABLED)
    target_sources(${PROJECT_NAME} PRIVATE graphics_api.c graphics_api.h)
    rayplate_configure_angle_application(${PROJECT_NAME})
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

if(BUILD_TESTING AND RAYPLATE_ANGLE_ENABLED)
    add_test(NAME graphics_api_help COMMAND ${PROJECT_NAME} --help)
    add_test(NAME graphics_api_invalid COMMAND ${PROJECT_NAME} --graphics-api=invalid)
    set_tests_properties(graphics_api_invalid PROPERTIES WILL_FAIL TRUE)
endif()
