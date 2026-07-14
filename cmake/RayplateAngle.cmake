include_guard(GLOBAL)

set(RAYPLATE_ANGLE_PROVIDER "DOWNLOAD" CACHE STRING
    "ANGLE runtime provider: DOWNLOAD, LOCAL, or OFF")
set_property(CACHE RAYPLATE_ANGLE_PROVIDER PROPERTY STRINGS DOWNLOAD LOCAL OFF)
set(RAYPLATE_ANGLE_ROOT "" CACHE PATH
    "Extracted ANGLE bundle or runtime directory used by the LOCAL provider")
set(RAYPLATE_ANGLE_ARCHIVE "" CACHE FILEPATH
    "Local rayplate ANGLE .tar.gz bundle used by the LOCAL provider")
set(RAYPLATE_ANGLE_LOCAL_SHA256 "" CACHE STRING
    "Optional SHA-256 for RAYPLATE_ANGLE_ARCHIVE")

function(_rayplate_angle_target_name output)
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
            string(TOUPPER "${RAYPLATE_ANGLE_PROVIDER}" provider)
            if(provider STREQUAL "DOWNLOAD")
                message(FATAL_ERROR
                    "The DOWNLOAD provider requires a single macOS architecture; "
                    "use separate arm64/x86_64 builds or RAYPLATE_ANGLE_PROVIDER=LOCAL with universal libraries")
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

function(_rayplate_find_unique_file output root filename required)
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

function(_rayplate_extract_angle_archive archive archive_hash destination)
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

function(_rayplate_create_windows_import_library output dll target_name)
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

function(_rayplate_define_angle_gles_target gles_path target_name)
    if(TARGET rayplate_angle_gles)
        return()
    endif()

    set(link_input "${gles_path}")
    if(WIN32)
        _rayplate_create_windows_import_library(link_input "${gles_path}" "${target_name}")
    endif()

    add_library(rayplate_angle_gles UNKNOWN IMPORTED GLOBAL)
    set_target_properties(rayplate_angle_gles PROPERTIES IMPORTED_LOCATION "${link_input}")
endfunction()

function(rayplate_prepare_angle)
    string(TOUPPER "${RAYPLATE_ANGLE_PROVIDER}" provider)
    if(EMSCRIPTEN OR PLATFORM STREQUAL "Web")
        set(RAYPLATE_ANGLE_ENABLED FALSE PARENT_SCOPE)
        return()
    endif()
    if(provider STREQUAL "OFF")
        set(RAYPLATE_ANGLE_ENABLED FALSE PARENT_SCOPE)
        return()
    endif()
    if(NOT provider STREQUAL "DOWNLOAD" AND NOT provider STREQUAL "LOCAL")
        message(FATAL_ERROR "RAYPLATE_ANGLE_PROVIDER must be DOWNLOAD, LOCAL, or OFF")
    endif()

    _rayplate_angle_target_name(target_name)
    string(REPLACE "-" "_" target_key "${target_name}")

    if(provider STREQUAL "DOWNLOAD")
        include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/AngleArtifacts.cmake")
        set(default_bundle_name
            "rayplate-angle-electron-${RAYPLATE_ANGLE_ELECTRON_VERSION}-${target_name}.tar.gz")
        set(default_release_base
            "https://github.com/${RAYPLATE_ANGLE_RELEASE_REPOSITORY}/releases/download/angle-electron-v${RAYPLATE_ANGLE_ELECTRON_VERSION}")
        set(hash_variable "RAYPLATE_ANGLE_BUNDLE_SHA256_${target_key}")
        set(default_hash "${${hash_variable}}")

        set(RAYPLATE_ANGLE_BUNDLE_NAME "" CACHE STRING
            "Override the default ANGLE release bundle filename")
        set(RAYPLATE_ANGLE_RELEASE_BASE_URL "" CACHE STRING
            "Override the default base URL containing the ANGLE release bundle")
        set(RAYPLATE_ANGLE_BUNDLE_SHA256 "" CACHE STRING
            "Override the locked SHA-256 of the ANGLE release bundle")

        set(bundle_name "${default_bundle_name}")
        set(release_base "${default_release_base}")
        set(bundle_hash "${default_hash}")
        if(RAYPLATE_ANGLE_BUNDLE_NAME)
            set(bundle_name "${RAYPLATE_ANGLE_BUNDLE_NAME}")
        endif()
        if(RAYPLATE_ANGLE_RELEASE_BASE_URL)
            set(release_base "${RAYPLATE_ANGLE_RELEASE_BASE_URL}")
        endif()
        if(RAYPLATE_ANGLE_BUNDLE_SHA256)
            set(bundle_hash "${RAYPLATE_ANGLE_BUNDLE_SHA256}")
        endif()

        string(LENGTH "${bundle_hash}" bundle_hash_length)
        if(NOT bundle_hash MATCHES "^[0-9a-fA-F]+$" OR
           NOT bundle_hash_length EQUAL 64)
            message(FATAL_ERROR
                "No valid locked ANGLE bundle hash exists for ${target_name}. "
                "Publish the matching angle-electron release and update cmake/AngleArtifacts.cmake, "
                "or configure RAYPLATE_ANGLE_PROVIDER=LOCAL.")
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
        _rayplate_extract_angle_archive(
            "${archive}" "${bundle_hash}" "${runtime_root}")
    else()
        if(RAYPLATE_ANGLE_ARCHIVE)
            if(NOT EXISTS "${RAYPLATE_ANGLE_ARCHIVE}")
                message(FATAL_ERROR "RAYPLATE_ANGLE_ARCHIVE does not exist: ${RAYPLATE_ANGLE_ARCHIVE}")
            endif()
            file(SHA256 "${RAYPLATE_ANGLE_ARCHIVE}" local_archive_hash)
            string(TOLOWER "${RAYPLATE_ANGLE_LOCAL_SHA256}" expected_local_archive_hash)
            if(expected_local_archive_hash AND
               NOT local_archive_hash STREQUAL expected_local_archive_hash)
                message(FATAL_ERROR
                    "Local ANGLE archive checksum mismatch: expected ${RAYPLATE_ANGLE_LOCAL_SHA256}, "
                    "got ${local_archive_hash}")
            endif()
            set(runtime_root "${CMAKE_BINARY_DIR}/_angle/local-${target_name}")
            _rayplate_extract_angle_archive(
                "${RAYPLATE_ANGLE_ARCHIVE}" "${local_archive_hash}" "${runtime_root}")
        elseif(RAYPLATE_ANGLE_ROOT)
            if(NOT IS_DIRECTORY "${RAYPLATE_ANGLE_ROOT}")
                message(FATAL_ERROR "RAYPLATE_ANGLE_ROOT is not a directory: ${RAYPLATE_ANGLE_ROOT}")
            endif()
            set(runtime_root "${RAYPLATE_ANGLE_ROOT}")
        else()
            message(FATAL_ERROR
                "The LOCAL provider requires RAYPLATE_ANGLE_ROOT or RAYPLATE_ANGLE_ARCHIVE")
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

    _rayplate_find_unique_file(egl_path "${runtime_root}" "${egl_name}" TRUE)
    _rayplate_find_unique_file(gles_path "${runtime_root}" "${gles_name}" TRUE)
    _rayplate_find_unique_file(d3dcompiler_path "${runtime_root}" "d3dcompiler_47.dll" FALSE)
    _rayplate_find_unique_file(electron_license "${runtime_root}" "ELECTRON-LICENSE" FALSE)
    _rayplate_find_unique_file(chromium_license "${runtime_root}" "LICENSES.chromium.html" FALSE)
    _rayplate_find_unique_file(angle_manifest "${runtime_root}" "manifest.json" FALSE)

    _rayplate_define_angle_gles_target("${gles_path}" "${target_name}")

    # raylib's desktop backend requests EGL for an OpenGL ES build. Force its
    # bundled GLFW so we can name the exact ANGLE libraries it must dlopen.
    set(PLATFORM "Desktop" CACHE STRING "raylib platform" FORCE)
    set(OPENGL_VERSION "ES 3.0" CACHE STRING "OpenGL Version to build raylib with" FORCE)
    set(GRAPHICS "GRAPHICS_API_OPENGL_ES3" CACHE STRING "raylib graphics API" FORCE)
    set(USE_EXTERNAL_GLFW "OFF" CACHE STRING "Use raylib's bundled GLFW" FORCE)

    set(RAYPLATE_ANGLE_ENABLED TRUE PARENT_SCOPE)
    set(RAYPLATE_ANGLE_TARGET "${target_name}" PARENT_SCOPE)
    set(RAYPLATE_ANGLE_EGL "${egl_path}" PARENT_SCOPE)
    set(RAYPLATE_ANGLE_GLES "${gles_path}" PARENT_SCOPE)
    set(RAYPLATE_ANGLE_D3DCOMPILER "${d3dcompiler_path}" PARENT_SCOPE)
    set(RAYPLATE_ANGLE_ELECTRON_LICENSE "${electron_license}" PARENT_SCOPE)
    set(RAYPLATE_ANGLE_CHROMIUM_LICENSE "${chromium_license}" PARENT_SCOPE)
    set(RAYPLATE_ANGLE_MANIFEST "${angle_manifest}" PARENT_SCOPE)
endfunction()

function(rayplate_configure_angle_raylib raylib_target)
    if(NOT RAYPLATE_ANGLE_ENABLED)
        return()
    endif()
    get_filename_component(egl_name "${RAYPLATE_ANGLE_EGL}" NAME)
    get_filename_component(gles_name "${RAYPLATE_ANGLE_GLES}" NAME)
    set(khronos_include "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../third_party/khronos")
    if(NOT EXISTS "${khronos_include}/GLES3/gl3.h")
        message(FATAL_ERROR "Bundled Khronos OpenGL ES headers are missing")
    endif()
    target_include_directories(${raylib_target} PUBLIC
        "$<BUILD_INTERFACE:${khronos_include}>")
    target_compile_definitions(${raylib_target} PRIVATE
        "_GLFW_EGL_LIBRARY=\"${egl_name}\""
        "_GLFW_GLESV2_LIBRARY=\"${gles_name}\""
    )
    if(TARGET glfw)
        target_compile_definitions(glfw PRIVATE
            "_GLFW_EGL_LIBRARY=\"${egl_name}\""
            "_GLFW_GLESV2_LIBRARY=\"${gles_name}\""
        )
    else()
        message(FATAL_ERROR "ANGLE requires raylib's bundled GLFW target")
    endif()
endfunction()

function(rayplate_configure_angle_application application_target)
    if(NOT RAYPLATE_ANGLE_ENABLED)
        return()
    endif()

    target_compile_definitions(${application_target} PRIVATE RAYPLATE_ANGLE_ENABLED=1)
    target_include_directories(${application_target} PRIVATE
        "${raylib_SOURCE_DIR}/src/external/glfw/include")
    # rlgl's ES3 implementation calls GLES symbols directly. Keep ANGLE after
    # the raylib static archive and before raylib's host OpenGL dependencies.
    target_link_libraries(${application_target} PRIVATE rayplate_angle_gles)

    set(runtime_files "${RAYPLATE_ANGLE_EGL}" "${RAYPLATE_ANGLE_GLES}")
    if(RAYPLATE_ANGLE_D3DCOMPILER)
        list(APPEND runtime_files "${RAYPLATE_ANGLE_D3DCOMPILER}")
    endif()
    foreach(runtime_file IN LISTS runtime_files)
        add_custom_command(TARGET ${application_target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${runtime_file}" "$<TARGET_FILE_DIR:${application_target}>"
            VERBATIM)
    endforeach()

    set(license_files "")
    foreach(license_file IN ITEMS
            "${RAYPLATE_ANGLE_ELECTRON_LICENSE}"
            "${RAYPLATE_ANGLE_CHROMIUM_LICENSE}"
            "${RAYPLATE_ANGLE_MANIFEST}")
        if(license_file)
            list(APPEND license_files "${license_file}")
        endif()
    endforeach()
    if(license_files)
        add_custom_command(TARGET ${application_target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_FILE_DIR:${application_target}>/angle-licenses"
            VERBATIM)
        foreach(license_file IN LISTS license_files)
            add_custom_command(TARGET ${application_target} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${license_file}"
                    "$<TARGET_FILE_DIR:${application_target}>/angle-licenses"
                VERBATIM)
        endforeach()
    endif()

    if(APPLE)
        set_property(TARGET ${application_target} APPEND PROPERTY BUILD_RPATH "@loader_path")
        set_property(TARGET ${application_target} APPEND PROPERTY INSTALL_RPATH "@loader_path")
        get_filename_component(gles_name "${RAYPLATE_ANGLE_GLES}" NAME)
        add_custom_command(TARGET ${application_target} POST_BUILD
            COMMAND "${CMAKE_INSTALL_NAME_TOOL}"
                -change "./${gles_name}" "@loader_path/${gles_name}"
                "$<TARGET_FILE:${application_target}>"
            VERBATIM)
    elseif(UNIX)
        set_property(TARGET ${application_target} APPEND PROPERTY BUILD_RPATH "$ORIGIN")
        set_property(TARGET ${application_target} APPEND PROPERTY INSTALL_RPATH "$ORIGIN")
    endif()
endfunction()
