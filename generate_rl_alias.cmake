if(NOT DEFINED RAYLIB_HEADER_PATH)
    message(FATAL_ERROR "RAYLIB_HEADER_PATH is required")
endif()

if(NOT DEFINED RL_ALIAS_HEADER_PATH)
    message(FATAL_ERROR "RL_ALIAS_HEADER_PATH is required")
endif()

if(NOT DEFINED RL_ALIAS_MODE)
    message(FATAL_ERROR "RL_ALIAS_MODE is required")
endif()

if(NOT DEFINED RL_ALIAS_PREFIX)
    set(RL_ALIAS_PREFIX "rl")
endif()

if(NOT EXISTS "${RAYLIB_HEADER_PATH}")
    message(FATAL_ERROR "Could not find raylib header: ${RAYLIB_HEADER_PATH}")
endif()

get_filename_component(RL_ALIAS_HEADER_DIR "${RL_ALIAS_HEADER_PATH}" DIRECTORY)
file(MAKE_DIRECTORY "${RL_ALIAS_HEADER_DIR}")

file(WRITE "${RL_ALIAS_HEADER_PATH}" "// Auto-generated alias file\n\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#ifndef _RL_ALIAS_H\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#define _RL_ALIAS_H\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#include <raylib.h>\n\n")

file(STRINGS "${RAYLIB_HEADER_PATH}" raylib_api_lines REGEX "^[ \t]*RLAPI[ \t]+.*\\);")

foreach(line IN LISTS raylib_api_lines)
    string(REGEX MATCH "^[ \t]*RLAPI[ \t]+(.+[\\* \t])([A-Za-z_][A-Za-z0-9_]*)[ \t]*\\(([^)]*)\\)[ \t]*;" _ "${line}")

    if(NOT CMAKE_MATCH_2)
        message(WARNING "Could not parse raylib API declaration: ${line}")
        continue()
    endif()

    string(STRIP "${CMAKE_MATCH_1}" return_type)
    set(function_name "${CMAKE_MATCH_2}")
    string(STRIP "${CMAKE_MATCH_3}" args)

    if(RL_ALIAS_MODE STREQUAL "DEFINE")
        file(APPEND "${RL_ALIAS_HEADER_PATH}" "#define ${RL_ALIAS_PREFIX}${function_name} ${function_name}\n")
    elseif(RL_ALIAS_MODE STREQUAL "INLINE")
        if(args MATCHES "\\.\\.\\.")
            # Variadic functions cannot be forwarded safely by a C99 inline
            # wrapper without a matching v* API, so use a macro alias for them.
            file(APPEND "${RL_ALIAS_HEADER_PATH}" "#define ${RL_ALIAS_PREFIX}${function_name} ${function_name}\n\n")
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

        file(APPEND "${RL_ALIAS_HEADER_PATH}" "static inline ${return_type} ${RL_ALIAS_PREFIX}${function_name}(${wrapper_args})\n")
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

file(APPEND "${RL_ALIAS_HEADER_PATH}" "#endif // _RL_ALIAS_H\n")
message(STATUS "Alias file generated: ${RL_ALIAS_HEADER_PATH}")

