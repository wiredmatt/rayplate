include_guard(GLOBAL)

set(GAME_ANGLE_PROVIDER "DOWNLOAD" CACHE STRING
    "ANGLE runtime provider: DOWNLOAD, LOCAL, or OFF")
set_property(CACHE GAME_ANGLE_PROVIDER PROPERTY STRINGS DOWNLOAD LOCAL OFF)
set(GAME_ANGLE_ROOT "" CACHE PATH
    "Extracted ANGLE bundle or runtime directory used by the LOCAL provider")
set(GAME_ANGLE_ARCHIVE "" CACHE FILEPATH
    "Local rayplate ANGLE .tar.gz bundle used by the LOCAL provider")
set(GAME_ANGLE_LOCAL_SHA256 "" CACHE STRING
    "Optional SHA-256 for GAME_ANGLE_ARCHIVE")
set(GAME_MACOS_ADHOC_SIGN ON CACHE BOOL
    "Ad-hoc sign the macOS app bundle and its ANGLE libraries")

function(_game_angle_target_name output)
    if(WIN32)
        set(platform windows)
    elseif(APPLE)
        set(platform macos)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        set(platform linux)
    else()
        message(FATAL_ERROR "ANGLE bundles are not available for ${CMAKE_SYSTEM_NAME}")
    endif()

    if(APPLE AND CMAKE_OSX_ARCHITECTURES)
        list(LENGTH CMAKE_OSX_ARCHITECTURES architecture_count)
        if(NOT architecture_count EQUAL 1)
            string(TOUPPER "${GAME_ANGLE_PROVIDER}" provider)
            if(provider STREQUAL "DOWNLOAD")
                message(FATAL_ERROR
                    "The DOWNLOAD provider requires a single macOS architecture; "
                    "use separate arm64/x86_64 builds or GAME_ANGLE_PROVIDER=LOCAL with universal libraries")
            endif()
            set(processor universal)
        else()
            list(GET CMAKE_OSX_ARCHITECTURES 0 processor)
        endif()
    elseif(MSVC_CXX_ARCHITECTURE_ID)
        set(processor "${MSVC_CXX_ARCHITECTURE_ID}")
    else()
        set(processor "${CMAKE_SYSTEM_PROCESSOR}")
    endif()
    string(TOLOWER "${processor}" processor)

    if(processor MATCHES "^(x86_64|amd64|x64)$")
        set(architecture x64)
    elseif(processor MATCHES "^(aarch64|arm64)$")
        set(architecture arm64)
    elseif(processor STREQUAL "universal")
        set(architecture universal)
    else()
        message(FATAL_ERROR "ANGLE bundles are not available for architecture '${processor}'")
    endif()

    set(${output} "${platform}-${architecture}" PARENT_SCOPE)
endfunction()

function(_game_find_unique_file output root filename required)
    file(GLOB_RECURSE candidates LIST_DIRECTORIES false "${root}/*")
    set(matches "")
    foreach(candidate IN LISTS candidates)
        get_filename_component(candidate_name "${candidate}" NAME)
        if(candidate_name STREQUAL filename)
            list(APPEND matches "${candidate}")
        endif()
    endforeach()
    list(LENGTH matches match_count)
    if(match_count GREATER 1)
        message(FATAL_ERROR "Found multiple ${filename} files below ${root}: ${matches}")
    elseif(match_count EQUAL 0)
        if(required)
            message(FATAL_ERROR "Could not find ${filename} below ${root}")
        endif()
        set(${output} "" PARENT_SCOPE)
    else()
        list(GET matches 0 match)
        set(${output} "${match}" PARENT_SCOPE)
    endif()
endfunction()

function(_game_extract_angle_archive archive archive_hash destination)
    set(marker "${destination}/.rayplate-angle-sha256")
    set(extract_required TRUE)
    if(EXISTS "${marker}")
        file(READ "${marker}" existing_hash)
        string(STRIP "${existing_hash}" existing_hash)
        if(existing_hash STREQUAL archive_hash)
            set(extract_required FALSE)
        endif()
    endif()

    if(extract_required)
        file(REMOVE_RECURSE "${destination}")
        file(MAKE_DIRECTORY "${destination}")
        file(ARCHIVE_EXTRACT INPUT "${archive}" DESTINATION "${destination}")
        file(WRITE "${marker}" "${archive_hash}\n")
    endif()
endfunction()

function(_game_create_windows_import_library output dll target_name)
    if(NOT MSVC)
        # GNU-family Windows linkers support linking a DLL directly.
        set(${output} "${dll}" PARENT_SCOPE)
        return()
    endif()

    if(target_name MATCHES "-arm64$")
        set(machine ARM64)
    else()
        set(machine X64)
    endif()

    set(import_dir "${CMAKE_BINARY_DIR}/_angle/import")
    set(definition "${import_dir}/libGLESv2.def")
    set(import_library "${import_dir}/libGLESv2.lib")
    file(MAKE_DIRECTORY "${import_dir}")

    # Electron ships DLLs but not MSVC import libraries. LINK /DUMP and LIB are
    # part of the selected Visual Studio toolchain, so no extra SDK is needed.
    execute_process(
        COMMAND "${CMAKE_LINKER}" /dump /exports "${dll}"
        RESULT_VARIABLE dump_result
        OUTPUT_VARIABLE dump_output
        ERROR_VARIABLE dump_error
    )
    if(NOT dump_result EQUAL 0)
        message(FATAL_ERROR "Could not inspect ANGLE exports: ${dump_error}")
    endif()
    string(REPLACE "\r" "" dump_output "${dump_output}")
    string(REGEX MATCHALL
        "\n[ \t]+[0-9]+[ \t]+[0-9A-Fa-f]+[ \t]+[0-9A-Fa-f]+[ \t]+[A-Za-z_][A-Za-z0-9_@?]*"
        export_lines "${dump_output}")
    list(LENGTH export_lines export_count)
    if(export_count LESS 100)
        message(FATAL_ERROR
            "Could not parse enough exports from ANGLE's libGLESv2.dll (found ${export_count})")
    endif()

    set(definition_contents "LIBRARY libGLESv2\nEXPORTS\n")
    foreach(export_line IN LISTS export_lines)
        string(REGEX REPLACE ".*[ \t]([^ \t\n]+)$" "\\1" export_name "${export_line}")
        string(APPEND definition_contents "    ${export_name}\n")
    endforeach()
    file(WRITE "${definition}" "${definition_contents}")

    execute_process(
        COMMAND "${CMAKE_AR}" /nologo "/def:${definition}" "/machine:${machine}"
        "/out:${import_library}"
        RESULT_VARIABLE library_result
        OUTPUT_VARIABLE library_output
        ERROR_VARIABLE library_error
    )
    if(NOT library_result EQUAL 0 OR NOT EXISTS "${import_library}")
        message(FATAL_ERROR
            "Could not create ANGLE import library: ${library_output}${library_error}")
    endif()
    set(${output} "${import_library}" PARENT_SCOPE)
endfunction()

function(_game_define_angle_gles_target gles_path target_name)
    if(TARGET game_angle_gles)
        return()
    endif()

    set(link_input "${gles_path}")
    if(WIN32)
        _game_create_windows_import_library(link_input "${gles_path}" "${target_name}")
    endif()

    add_library(game_angle_gles UNKNOWN IMPORTED GLOBAL)
    set_target_properties(game_angle_gles PROPERTIES IMPORTED_LOCATION "${link_input}")
endfunction()

function(_game_patch_glfw_angle_x11 glfw_target)
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
        return()
    endif()

    # EGL_EXT_platform_x11 takes a pointer to the X11 Window ID, while
    # EGL_PLATFORM_ANGLE_ANGLE takes the Window ID itself even when its native
    # platform attribute is X11.  GLFW 3.4 treats every nonzero EGL platform
    # as EGL_EXT_platform_x11, which makes ANGLE reject the native window and
    # can subsequently crash while unwinding window creation.
    get_target_property(glfw_source_directory ${glfw_target} SOURCE_DIR)
    set(original_window_source "${glfw_source_directory}/x11_window.c")
    set(original_init_source "${glfw_source_directory}/x11_init.c")
    if(NOT EXISTS "${original_window_source}" OR NOT EXISTS "${original_init_source}")
        message(FATAL_ERROR "Could not find GLFW's X11 sources in ${glfw_source_directory}")
    endif()

    file(READ "${original_window_source}" window_contents)
    set(unpatched_condition "if (_glfw.egl.platform)\n        return &window->x11.handle;")
    set(patched_condition "if (_glfw.egl.platform == EGL_PLATFORM_X11_EXT)\n        return &window->x11.handle;")
    string(FIND "${window_contents}" "${unpatched_condition}" condition_offset)
    if(condition_offset EQUAL -1)
        message(FATAL_ERROR
            "GLFW's X11 EGL window handling changed; review the ANGLE compatibility patch")
    endif()
    string(REPLACE "${unpatched_condition}" "${patched_condition}"
        patched_window_contents "${window_contents}")

    # GLFW deliberately unloads EGL after XCloseDisplay so Xlib cleanup
    # callbacks remain valid.  ANGLE's OpenGL renderer, however, must destroy
    # its GLX objects before that display is closed.  Terminate the EGL display
    # early but leave the EGL module loaded for GLFW's existing late cleanup.
    file(READ "${original_init_source}" init_contents)
    set(unpatched_shutdown
        "    if (_glfw.x11.display)\n    {\n        XCloseDisplay(_glfw.x11.display);")
    set(patched_shutdown
        "    if (_glfw.egl.display)\n    {\n        eglTerminate(_glfw.egl.display);\n        _glfw.egl.display = EGL_NO_DISPLAY;\n    }\n\n    if (_glfw.x11.display)\n    {\n        XCloseDisplay(_glfw.x11.display);")
    string(FIND "${init_contents}" "${unpatched_shutdown}" shutdown_offset)
    if(shutdown_offset EQUAL -1)
        message(FATAL_ERROR
            "GLFW's X11 termination changed; review the ANGLE compatibility patch")
    endif()
    string(REPLACE "${unpatched_shutdown}" "${patched_shutdown}"
        patched_init_contents "${init_contents}")

    set(patched_directory "${CMAKE_BINARY_DIR}/_angle/glfw")
    set(patched_window_source "${patched_directory}/x11_window.c")
    set(patched_init_source "${patched_directory}/x11_init.c")
    file(MAKE_DIRECTORY "${patched_directory}")
    file(WRITE "${patched_window_source}" "${patched_window_contents}")
    file(WRITE "${patched_init_source}" "${patched_init_contents}")

    get_target_property(glfw_sources ${glfw_target} SOURCES)
    set(updated_sources "")
    set(window_replacement_count 0)
    set(init_replacement_count 0)
    foreach(source IN LISTS glfw_sources)
        if(IS_ABSOLUTE "${source}")
            set(absolute_source "${source}")
        else()
            get_filename_component(absolute_source "${source}" ABSOLUTE
                BASE_DIR "${glfw_source_directory}")
        endif()
        if(absolute_source STREQUAL original_window_source)
            list(APPEND updated_sources "${patched_window_source}")
            math(EXPR window_replacement_count "${window_replacement_count} + 1")
        elseif(absolute_source STREQUAL original_init_source)
            list(APPEND updated_sources "${patched_init_source}")
            math(EXPR init_replacement_count "${init_replacement_count} + 1")
        else()
            list(APPEND updated_sources "${source}")
        endif()
    endforeach()
    if(NOT window_replacement_count EQUAL 1 OR NOT init_replacement_count EQUAL 1)
        message(FATAL_ERROR
            "Expected one each of GLFW x11_window.c and x11_init.c, found "
            "${window_replacement_count} and ${init_replacement_count}")
    endif()
    set_property(TARGET ${glfw_target} PROPERTY SOURCES "${updated_sources}")
endfunction()

function(game_prepare_angle)
    string(TOUPPER "${GAME_ANGLE_PROVIDER}" provider)
    if(EMSCRIPTEN OR PLATFORM STREQUAL "Web")
        set(GAME_ANGLE_ENABLED FALSE PARENT_SCOPE)
        return()
    endif()
    if(provider STREQUAL "OFF")
        set(GAME_ANGLE_ENABLED FALSE PARENT_SCOPE)
        return()
    endif()
    if(NOT provider STREQUAL "DOWNLOAD" AND NOT provider STREQUAL "LOCAL")
        message(FATAL_ERROR "GAME_ANGLE_PROVIDER must be DOWNLOAD, LOCAL, or OFF")
    endif()

    _game_angle_target_name(target_name)
    string(REPLACE "-" "_" target_key "${target_name}")

    if(provider STREQUAL "DOWNLOAD")
        include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/AngleArtifacts.cmake")
        set(default_bundle_name
            "rayplate-angle-electron-${GAME_ANGLE_ELECTRON_VERSION}-${target_name}.tar.gz")
        set(default_release_base
            "https://github.com/${GAME_ANGLE_RELEASE_REPOSITORY}/releases/download/${GAME_ANGLE_RELEASE_TAG}")
        set(hash_variable "GAME_ANGLE_BUNDLE_SHA256_${target_key}")
        set(default_hash "${${hash_variable}}")

        set(GAME_ANGLE_BUNDLE_NAME "" CACHE STRING
            "Override the default ANGLE release bundle filename")
        set(GAME_ANGLE_RELEASE_BASE_URL "" CACHE STRING
            "Override the default base URL containing the ANGLE release bundle")
        set(GAME_ANGLE_BUNDLE_SHA256 "" CACHE STRING
            "Override the locked SHA-256 of the ANGLE release bundle")

        set(bundle_name "${default_bundle_name}")
        set(release_base "${default_release_base}")
        set(bundle_hash "${default_hash}")
        if(GAME_ANGLE_BUNDLE_NAME)
            set(bundle_name "${GAME_ANGLE_BUNDLE_NAME}")
        endif()
        if(GAME_ANGLE_RELEASE_BASE_URL)
            set(release_base "${GAME_ANGLE_RELEASE_BASE_URL}")
        endif()
        if(GAME_ANGLE_BUNDLE_SHA256)
            set(bundle_hash "${GAME_ANGLE_BUNDLE_SHA256}")
        endif()

        string(LENGTH "${bundle_hash}" bundle_hash_length)
        if(NOT bundle_hash MATCHES "^[0-9a-fA-F]+$" OR
            NOT bundle_hash_length EQUAL 64)
            message(FATAL_ERROR
                "No valid locked ANGLE bundle hash exists for ${target_name}. "
                "Publish the matching angle-electron release and update cmake/AngleArtifacts.cmake, "
                "or configure GAME_ANGLE_PROVIDER=LOCAL.")
        endif()
        string(TOLOWER "${bundle_hash}" bundle_hash)

        set(download_dir "${CMAKE_BINARY_DIR}/_downloads")
        set(archive "${download_dir}/${bundle_name}")
        file(MAKE_DIRECTORY "${download_dir}")
        file(DOWNLOAD
            "${release_base}/${bundle_name}"
            "${archive}"
            EXPECTED_HASH "SHA256=${bundle_hash}"
            STATUS download_status
            TLS_VERIFY ON
            SHOW_PROGRESS
        )
        list(GET download_status 0 download_code)
        list(GET download_status 1 download_message)
        if(NOT download_code EQUAL 0)
            message(FATAL_ERROR "Could not download ANGLE bundle: ${download_message}")
        endif()

        set(runtime_root "${CMAKE_BINARY_DIR}/_angle/${target_name}")
        _game_extract_angle_archive(
            "${archive}" "${bundle_hash}" "${runtime_root}")
    else()
        if(GAME_ANGLE_ARCHIVE)
            if(NOT EXISTS "${GAME_ANGLE_ARCHIVE}")
                message(FATAL_ERROR "GAME_ANGLE_ARCHIVE does not exist: ${GAME_ANGLE_ARCHIVE}")
            endif()
            file(SHA256 "${GAME_ANGLE_ARCHIVE}" local_archive_hash)
            string(TOLOWER "${GAME_ANGLE_LOCAL_SHA256}" expected_local_archive_hash)
            if(expected_local_archive_hash AND
                NOT local_archive_hash STREQUAL expected_local_archive_hash)
                message(FATAL_ERROR
                    "Local ANGLE archive checksum mismatch: expected ${GAME_ANGLE_LOCAL_SHA256}, "
                    "got ${local_archive_hash}")
            endif()
            set(runtime_root "${CMAKE_BINARY_DIR}/_angle/local-${target_name}")
            _game_extract_angle_archive(
                "${GAME_ANGLE_ARCHIVE}" "${local_archive_hash}" "${runtime_root}")
        elseif(GAME_ANGLE_ROOT)
            if(NOT IS_DIRECTORY "${GAME_ANGLE_ROOT}")
                message(FATAL_ERROR "GAME_ANGLE_ROOT is not a directory: ${GAME_ANGLE_ROOT}")
            endif()
            set(runtime_root "${GAME_ANGLE_ROOT}")
        else()
            message(FATAL_ERROR
                "The LOCAL provider requires GAME_ANGLE_ROOT or GAME_ANGLE_ARCHIVE")
        endif()
    endif()

    if(WIN32)
        set(egl_name libEGL.dll)
        set(gles_name libGLESv2.dll)
    elseif(APPLE)
        set(egl_name libEGL.dylib)
        set(gles_name libGLESv2.dylib)
    else()
        set(egl_name libEGL.so)
        set(gles_name libGLESv2.so)
    endif()

    _game_find_unique_file(egl_path "${runtime_root}" "${egl_name}" TRUE)
    _game_find_unique_file(gles_path "${runtime_root}" "${gles_name}" TRUE)
    _game_find_unique_file(d3dcompiler_path "${runtime_root}" "d3dcompiler_47.dll" FALSE)
    _game_find_unique_file(vulkan_loader_path "${runtime_root}" "libvulkan.so.1" FALSE)
    _game_find_unique_file(electron_license "${runtime_root}" "ELECTRON-LICENSE" FALSE)
    _game_find_unique_file(chromium_license "${runtime_root}" "LICENSES.chromium.html" FALSE)
    _game_find_unique_file(angle_manifest "${runtime_root}" "manifest.json" FALSE)

    _game_define_angle_gles_target("${gles_path}" "${target_name}")

    # raylib's desktop backend requests EGL for an OpenGL ES build. Force its
    # bundled GLFW so we can name the exact ANGLE libraries it must dlopen.
    set(PLATFORM "Desktop" CACHE STRING "raylib platform" FORCE)
    set(OPENGL_VERSION "ES 3.0" CACHE STRING "OpenGL Version to build raylib with" FORCE)
    set(GRAPHICS "GRAPHICS_API_OPENGL_ES3" CACHE STRING "raylib graphics API" FORCE)
    set(USE_EXTERNAL_GLFW "OFF" CACHE STRING "Use raylib's bundled GLFW" FORCE)

    set(GAME_ANGLE_ENABLED TRUE PARENT_SCOPE)
    set(GAME_ANGLE_TARGET "${target_name}" PARENT_SCOPE)
    set(GAME_ANGLE_EGL "${egl_path}" PARENT_SCOPE)
    set(GAME_ANGLE_GLES "${gles_path}" PARENT_SCOPE)
    set(GAME_ANGLE_D3DCOMPILER "${d3dcompiler_path}" PARENT_SCOPE)
    set(GAME_ANGLE_VULKAN_LOADER "${vulkan_loader_path}" PARENT_SCOPE)
    set(GAME_ANGLE_ELECTRON_LICENSE "${electron_license}" PARENT_SCOPE)
    set(GAME_ANGLE_CHROMIUM_LICENSE "${chromium_license}" PARENT_SCOPE)
    set(GAME_ANGLE_MANIFEST "${angle_manifest}" PARENT_SCOPE)
endfunction()

function(game_configure_angle_raylib raylib_target)
    if(NOT GAME_ANGLE_ENABLED)
        return()
    endif()
    get_filename_component(egl_name "${GAME_ANGLE_EGL}" NAME)
    get_filename_component(gles_name "${GAME_ANGLE_GLES}" NAME)
    if(APPLE)
        set(egl_runtime_name "@executable_path/../Frameworks/${egl_name}")
        set(gles_runtime_name "@executable_path/../Frameworks/${gles_name}")
    else()
        set(egl_runtime_name "${egl_name}")
        set(gles_runtime_name "${gles_name}")
    endif()
    set(khronos_include "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../third_party/khronos")
    if(NOT EXISTS "${khronos_include}/GLES3/gl3.h")
        message(FATAL_ERROR "Bundled Khronos OpenGL ES headers are missing")
    endif()
    target_include_directories(${raylib_target} PUBLIC
        "$<BUILD_INTERFACE:${khronos_include}>")
    target_compile_definitions(${raylib_target} PRIVATE
        "_GLFW_EGL_LIBRARY=\"${egl_runtime_name}\""
        "_GLFW_GLESV2_LIBRARY=\"${gles_runtime_name}\""
    )
    if(TARGET glfw)
        _game_patch_glfw_angle_x11(glfw)
        target_compile_definitions(glfw PRIVATE
            "_GLFW_EGL_LIBRARY=\"${egl_runtime_name}\""
            "_GLFW_GLESV2_LIBRARY=\"${gles_runtime_name}\""
        )
    else()
        message(FATAL_ERROR "ANGLE requires raylib's bundled GLFW target")
    endif()
endfunction()

function(game_configure_angle_application application_target)
    if(NOT GAME_ANGLE_ENABLED)
        return()
    endif()

    target_compile_definitions(${application_target} PRIVATE GAME_ANGLE_ENABLED=1)
    target_include_directories(${application_target} PRIVATE
        "${raylib_SOURCE_DIR}/src/external/glfw/include")
    # rlgl's ES3 implementation calls GLES symbols directly. Keep ANGLE after
    # the raylib static archive and before raylib's host OpenGL dependencies.
    target_link_libraries(${application_target} PRIVATE game_angle_gles)

    set(runtime_files "${GAME_ANGLE_EGL}" "${GAME_ANGLE_GLES}")
    if(GAME_ANGLE_D3DCOMPILER)
        list(APPEND runtime_files "${GAME_ANGLE_D3DCOMPILER}")
    endif()
    if(GAME_ANGLE_VULKAN_LOADER)
        list(APPEND runtime_files "${GAME_ANGLE_VULKAN_LOADER}")
    endif()
    if(APPLE)
        set(bundle_directory "$<TARGET_BUNDLE_DIR:${application_target}>")
        set(runtime_destination "${bundle_directory}/Contents/Frameworks")
        set(license_destination "${bundle_directory}/Contents/Resources/angle-licenses")
        add_custom_command(TARGET ${application_target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "${runtime_destination}"
            VERBATIM)
    else()
        set(runtime_destination "$<TARGET_FILE_DIR:${application_target}>")
        set(license_destination
            "$<TARGET_FILE_DIR:${application_target}>/angle-licenses")
    endif()
    foreach(runtime_file IN LISTS runtime_files)
        add_custom_command(TARGET ${application_target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${runtime_file}" "${runtime_destination}"
            VERBATIM)
    endforeach()

    set(license_files "")
    foreach(license_file IN ITEMS
        "${GAME_ANGLE_ELECTRON_LICENSE}"
        "${GAME_ANGLE_CHROMIUM_LICENSE}"
        "${GAME_ANGLE_MANIFEST}")
        if(license_file)
            list(APPEND license_files "${license_file}")
        endif()
    endforeach()
    if(license_files)
        add_custom_command(TARGET ${application_target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory
            "${license_destination}"
            VERBATIM)
        foreach(license_file IN LISTS license_files)
            add_custom_command(TARGET ${application_target} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${license_file}"
                "${license_destination}"
                VERBATIM)
        endforeach()
    endif()

    if(APPLE)
        set_property(TARGET ${application_target} APPEND PROPERTY
            BUILD_RPATH "@executable_path/../Frameworks")
        set_property(TARGET ${application_target} APPEND PROPERTY
            INSTALL_RPATH "@executable_path/../Frameworks")
        get_filename_component(gles_name "${GAME_ANGLE_GLES}" NAME)
        add_custom_command(TARGET ${application_target} POST_BUILD
            COMMAND "${CMAKE_INSTALL_NAME_TOOL}"
            -change "./${gles_name}"
            "@executable_path/../Frameworks/${gles_name}"
            "$<TARGET_FILE:${application_target}>"
            VERBATIM)

        if(GAME_MACOS_ADHOC_SIGN)
            find_program(game_codesign codesign REQUIRED)
            foreach(runtime_file IN LISTS runtime_files)
                get_filename_component(runtime_name "${runtime_file}" NAME)
                add_custom_command(TARGET ${application_target} POST_BUILD
                    COMMAND "${game_codesign}" --force --sign -
                    "${runtime_destination}/${runtime_name}"
                    VERBATIM)
            endforeach()
            add_custom_command(TARGET ${application_target} POST_BUILD
                COMMAND "${game_codesign}" --force --sign - "${bundle_directory}"
                COMMAND "${game_codesign}" --verify --deep --strict --verbose=2
                "${bundle_directory}"
                VERBATIM)
        endif()
    elseif(UNIX)
        set_property(TARGET ${application_target} APPEND PROPERTY BUILD_RPATH "$ORIGIN")
        set_property(TARGET ${application_target} APPEND PROPERTY INSTALL_RPATH "$ORIGIN")
    endif()
endfunction()
