if(NOT DEFINED RAYLIB_HEADER_PATH)
    message(FATAL_ERROR "RAYLIB_HEADER_PATH is required")
endif()

if(NOT DEFINED RLGL_HEADER_PATH)
    message(FATAL_ERROR "RLGL_HEADER_PATH is required")
endif()

if(NOT DEFINED RL_ALIAS_HEADER_PATH)
    message(FATAL_ERROR "RL_ALIAS_HEADER_PATH is required")
endif()

if(NOT DEFINED RL_ALIAS_MODE)
    message(FATAL_ERROR "RL_ALIAS_MODE is required")
endif()

if(NOT DEFINED RAYLIB_ALIAS_PREFIX)
    set(RAYLIB_ALIAS_PREFIX "RLIB_")
endif()

if(NOT DEFINED RLGL_ALIAS_PREFIX)
    set(RLGL_ALIAS_PREFIX "RLGL_")
endif()

foreach(prefix_variable IN ITEMS RAYLIB_ALIAS_PREFIX RLGL_ALIAS_PREFIX)
    if("${${prefix_variable}}" STREQUAL "")
        message(FATAL_ERROR "${prefix_variable} must not be empty")
    endif()

    if(NOT "${${prefix_variable}}" MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
        message(FATAL_ERROR "${prefix_variable} must be a valid C identifier prefix: '${${prefix_variable}}'")
    endif()
endforeach()

if(RAYLIB_ALIAS_PREFIX STREQUAL RLGL_ALIAS_PREFIX)
    message(FATAL_ERROR "RAYLIB_ALIAS_PREFIX and RLGL_ALIAS_PREFIX must differ to keep the APIs collision-free")
endif()

if(NOT EXISTS "${RAYLIB_HEADER_PATH}")
    message(FATAL_ERROR "Could not find raylib header: ${RAYLIB_HEADER_PATH}")
endif()

if(NOT EXISTS "${RLGL_HEADER_PATH}")
    message(FATAL_ERROR "Could not find rlgl header: ${RLGL_HEADER_PATH}")
endif()

get_filename_component(RL_ALIAS_HEADER_DIR "${RL_ALIAS_HEADER_PATH}" DIRECTORY)
file(MAKE_DIRECTORY "${RL_ALIAS_HEADER_DIR}")

file(WRITE "${RL_ALIAS_HEADER_PATH}" "// Auto-generated alias file\n\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#ifndef _RL_ALIAS_H\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#define _RL_ALIAS_H\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#include <raylib.h>\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#include <rlgl.h>\n\n")

function(generate_api_aliases API_NAME HEADER_PATH ALIAS_PREFIX)
    file(APPEND "${RL_ALIAS_HEADER_PATH}" "// ${API_NAME} aliases (${ALIAS_PREFIX}*)\n")
    file(STRINGS "${HEADER_PATH}" api_lines REGEX "^[ \t]*RLAPI[ \t]+.*\\);")

    foreach(line IN LISTS api_lines)
        string(REGEX MATCH "^[ \t]*RLAPI[ \t]+(.+[\\* \t])([A-Za-z_][A-Za-z0-9_]*)[ \t]*\\(([^)]*)\\)[ \t]*;" _ "${line}")

        if(NOT CMAKE_MATCH_2)
            message(WARNING "Could not parse ${API_NAME} API declaration: ${line}")
            continue()
        endif()

        string(STRIP "${CMAKE_MATCH_1}" return_type)
        set(function_name "${CMAKE_MATCH_2}")
        string(STRIP "${CMAKE_MATCH_3}" args)

        if(API_NAME STREQUAL "rlgl")
            # rlgl mostly uses an rl* prefix, with a few existing rlgl* names.
            # Normalize both forms into one configurable rlgl* namespace.
            if(function_name MATCHES "^rlgl(.+)$")
                set(function_suffix "${CMAKE_MATCH_1}")
            elseif(function_name MATCHES "^rl(.+)$")
                set(function_suffix "${CMAKE_MATCH_1}")
            else()
                set(function_suffix "${function_name}")
            endif()
            set(alias_name "${ALIAS_PREFIX}${function_suffix}")
        else()
            set(alias_name "${ALIAS_PREFIX}${function_name}")
        endif()

        # A handful of rlgl functions already use the desired rlgl* spelling.
        if(alias_name STREQUAL function_name)
            continue()
        endif()

        if(RL_ALIAS_MODE STREQUAL "DEFINE")
            file(APPEND "${RL_ALIAS_HEADER_PATH}" "#define ${alias_name} ${function_name}\n")
        elseif(RL_ALIAS_MODE STREQUAL "INLINE")
            if(args MATCHES "\\.\\.\\.")
                # Variadic functions cannot be forwarded safely by a C99 inline
                # wrapper without a matching v* API, so use a macro alias for them.
                file(APPEND "${RL_ALIAS_HEADER_PATH}" "#define ${alias_name} ${function_name}\n\n")
                continue()
            endif()

            if(args STREQUAL "void")
                set(wrapper_args "void")
                set(call_args "")
            else()
                set(wrapper_args "${args}")
                set(call_args "")
                string(REPLACE "," ";" split_args "${args}")

                foreach(arg IN LISTS split_args)
                    string(STRIP "${arg}" arg)
                    string(REGEX REPLACE "[ \t]*\\[[^]]*\\]" "" arg_without_array "${arg}")
                    string(REGEX MATCH "([A-Za-z_][A-Za-z0-9_]*)[ \t]*$" arg_name "${arg_without_array}")

                    if(NOT arg_name)
                        message(FATAL_ERROR "Could not parse argument name from '${arg}' in ${function_name}()")
                    endif()

                    if(call_args STREQUAL "")
                        set(call_args "${arg_name}")
                    else()
                        set(call_args "${call_args}, ${arg_name}")
                    endif()
                endforeach()
            endif()

            file(APPEND "${RL_ALIAS_HEADER_PATH}" "static inline ${return_type} ${alias_name}(${wrapper_args})\n")
            file(APPEND "${RL_ALIAS_HEADER_PATH}" "{\n")

            if(return_type STREQUAL "void")
                file(APPEND "${RL_ALIAS_HEADER_PATH}" "    ${function_name}(${call_args});\n")
            else()
                file(APPEND "${RL_ALIAS_HEADER_PATH}" "    return ${function_name}(${call_args});\n")
            endif()

            file(APPEND "${RL_ALIAS_HEADER_PATH}" "}\n\n")
        else()
            message(FATAL_ERROR "${RL_ALIAS_MODE} mode is not supported.")
        endif()
    endforeach()

    file(APPEND "${RL_ALIAS_HEADER_PATH}" "\n")
endfunction()

function(generate_constant_aliases API_NAME HEADER_PATH ALIAS_PREFIX STRIP_RL_PREFIX)
    file(APPEND "${RL_ALIAS_HEADER_PATH}" "// ${API_NAME} constant aliases (${ALIAS_PREFIX}*)\n")

    # Object-like macros are values only when their original declaration is
    # active. Preserve that behavior instead of making conditional platform or
    # feature macros appear defined on every build.
    file(STRINGS "${HEADER_PATH}" macro_lines
        REGEX "^[ \t]*#define[ \t]+[A-Z][A-Z0-9_]*([ \t]|$)")
    set(macro_names "")
    foreach(line IN LISTS macro_lines)
        string(REGEX MATCH "#define[ \t]+([A-Z][A-Z0-9_]*)" _ "${line}")
        set(constant_name "${CMAKE_MATCH_1}")

        # Header guards, export annotations, and cross-module type guards are
        # preprocessor machinery rather than values used at API call sites.
        if(constant_name STREQUAL "RAYLIB_H" OR
           constant_name STREQUAL "RLGL_H" OR
           constant_name STREQUAL "RLAPI" OR
           constant_name MATCHES "^RL_.*_TYPE$")
            continue()
        endif()

        list(APPEND macro_names "${constant_name}")
        set(suffix "${constant_name}")
        if(STRIP_RL_PREFIX AND suffix MATCHES "^RL_(.+)$")
            set(suffix "${CMAKE_MATCH_1}")
        endif()
        set(alias_name "${ALIAS_PREFIX}${suffix}")
        if(NOT alias_name STREQUAL constant_name)
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "#if defined(${constant_name})\n"
                "#define ${alias_name} ${constant_name}\n"
                "#endif\n")
        endif()
    endforeach()

    # Enum members are identifiers rather than preprocessor macros, so alias
    # them directly. This covers keys, mouse buttons, flags, formats, and the
    # other public value sets declared by raylib and rlgl.
    file(STRINGS "${HEADER_PATH}" enum_lines
        REGEX "^[ \t]+[A-Z][A-Z0-9_]*[ \t]*(=[^,]+)?[,]?[ \t]*(//.*)?$")
    foreach(line IN LISTS enum_lines)
        string(REGEX MATCH "^[ \t]+([A-Z][A-Z0-9_]*)" _ "${line}")
        set(constant_name "${CMAKE_MATCH_1}")
        list(FIND macro_names "${constant_name}" macro_index)
        if(NOT macro_index EQUAL -1)
            continue()
        endif()

        set(suffix "${constant_name}")
        if(STRIP_RL_PREFIX AND suffix MATCHES "^RL_(.+)$")
            set(suffix "${CMAKE_MATCH_1}")
        endif()
        set(alias_name "${ALIAS_PREFIX}${suffix}")
        if(NOT alias_name STREQUAL constant_name)
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "#define ${alias_name} ${constant_name}\n")
        endif()
    endforeach()

    file(APPEND "${RL_ALIAS_HEADER_PATH}" "\n")
endfunction()

generate_constant_aliases("raylib" "${RAYLIB_HEADER_PATH}" "${RAYLIB_ALIAS_PREFIX}" TRUE)
generate_api_aliases("raylib" "${RAYLIB_HEADER_PATH}" "${RAYLIB_ALIAS_PREFIX}")
generate_constant_aliases("rlgl" "${RLGL_HEADER_PATH}" "${RLGL_ALIAS_PREFIX}" TRUE)
generate_api_aliases("rlgl" "${RLGL_HEADER_PATH}" "${RLGL_ALIAS_PREFIX}")

file(APPEND "${RL_ALIAS_HEADER_PATH}" "#endif // _RL_ALIAS_H\n")
message(STATUS "Alias file generated: ${RL_ALIAS_HEADER_PATH}")
