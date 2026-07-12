cmake_minimum_required(VERSION 3.25)
add_executable(${PROJECT_NAME})

target_sources(${PROJECT_NAME} PRIVATE main.c)
target_link_libraries(${PROJECT_NAME} PRIVATE raylib)

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
