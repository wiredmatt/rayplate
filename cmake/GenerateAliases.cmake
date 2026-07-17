cmake_policy(VERSION 3.25)

if(NOT DEFINED RAYLIB_HEADER_PATH)
    message(FATAL_ERROR "RAYLIB_HEADER_PATH is required")
endif()

if(NOT DEFINED RLGL_HEADER_PATH)
    message(FATAL_ERROR "RLGL_HEADER_PATH is required")
endif()

if(DEFINED IM_ALIAS_HEADER_PATH)
    if(NOT DEFINED RLIMGUI_HEADER_PATH)
        message(FATAL_ERROR "RLIMGUI_HEADER_PATH is required when generating im_alias.h")
    endif()

    if(NOT DEFINED CIMGUI_HEADER_PATH)
        message(FATAL_ERROR "CIMGUI_HEADER_PATH is required when generating im_alias.h")
    endif()
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

set(prefix_variables
    RAYLIB_ALIAS_PREFIX
    RLGL_ALIAS_PREFIX
)
if(DEFINED IM_ALIAS_HEADER_PATH)
    if(NOT DEFINED RLIMGUI_ALIAS_PREFIX)
        set(RLIMGUI_ALIAS_PREFIX "RGUI_")
    endif()

    if(NOT DEFINED CIMGUI_ALIAS_PREFIX)
        set(CIMGUI_ALIAS_PREFIX "IMGUI_")
    endif()

    list(APPEND prefix_variables RLIMGUI_ALIAS_PREFIX CIMGUI_ALIAS_PREFIX)
endif()
foreach(prefix_variable IN LISTS prefix_variables)
    if("${${prefix_variable}}" STREQUAL "")
        message(FATAL_ERROR "${prefix_variable} must not be empty")
    endif()

    if(NOT "${${prefix_variable}}" MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
        message(FATAL_ERROR "${prefix_variable} must be a valid C identifier prefix: '${${prefix_variable}}'")
    endif()
endforeach()

list(LENGTH prefix_variables prefix_count)
math(EXPR prefix_last_index "${prefix_count} - 1")
foreach(prefix_index RANGE 0 ${prefix_last_index})
    list(GET prefix_variables ${prefix_index} prefix_variable)
    math(EXPR other_prefix_start "${prefix_index} + 1")
    if(other_prefix_start LESS prefix_count)
        foreach(other_prefix_index RANGE ${other_prefix_start} ${prefix_last_index})
            list(GET prefix_variables ${other_prefix_index} other_prefix_variable)
            if("${${prefix_variable}}" STREQUAL "${${other_prefix_variable}}")
                message(FATAL_ERROR
                    "${prefix_variable} and ${other_prefix_variable} must differ "
                    "to keep the APIs collision-free")
            endif()
        endforeach()
    endif()
endforeach()

if(NOT EXISTS "${RAYLIB_HEADER_PATH}")
    message(FATAL_ERROR "Could not find raylib header: ${RAYLIB_HEADER_PATH}")
endif()

if(NOT EXISTS "${RLGL_HEADER_PATH}")
    message(FATAL_ERROR "Could not find rlgl header: ${RLGL_HEADER_PATH}")
endif()

if(DEFINED IM_ALIAS_HEADER_PATH)
    if(NOT EXISTS "${RLIMGUI_HEADER_PATH}")
        message(FATAL_ERROR "Could not find rlImGui header: ${RLIMGUI_HEADER_PATH}")
    endif()

    if(NOT EXISTS "${CIMGUI_HEADER_PATH}")
        message(FATAL_ERROR "Could not find cimgui header: ${CIMGUI_HEADER_PATH}")
    endif()
endif()

get_filename_component(RL_ALIAS_HEADER_DIR "${RL_ALIAS_HEADER_PATH}" DIRECTORY)
file(MAKE_DIRECTORY "${RL_ALIAS_HEADER_DIR}")

file(WRITE "${RL_ALIAS_HEADER_PATH}" "// Auto-generated alias file\n\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#ifndef _RL_ALIAS_H\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#define _RL_ALIAS_H\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#include <raylib.h>\n")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#include <rlgl.h>\n\n")

function(generate_api_aliases API_NAME HEADER_PATH ALIAS_PREFIX DECLARATION_REGEX)
    file(APPEND "${RL_ALIAS_HEADER_PATH}" "// ${API_NAME} aliases (${ALIAS_PREFIX}*)\n")
    file(STRINGS "${HEADER_PATH}" api_lines REGEX "${DECLARATION_REGEX}")

    foreach(line IN LISTS api_lines)
        string(REGEX REPLACE
            "^[ \t]*(RLAPI|RLIMGUIAPI)[ \t]+" "" declaration "${line}")
        string(REGEX MATCH "^(.+[\\* \t])([A-Za-z_][A-Za-z0-9_]*)[ \t]*\\(([^)]*)\\)[ \t]*;" _ "${declaration}")

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
        elseif(API_NAME STREQUAL "rlImGui")
            if(function_name STREQUAL "rlImGuiBegin")
                set(function_suffix "BeginFrame")
            elseif(function_name STREQUAL "rlImGuiEnd")
                set(function_suffix "EndFrame")
            else()
                string(REGEX REPLACE "^rlImGui" "" function_suffix "${function_name}")
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

function(get_cimgui_alias_suffix ORIGINAL_NAME OUTPUT_VARIABLE)
    if(ORIGINAL_NAME MATCHES "^ig(.+)$")
        set(alias_suffix "${CMAKE_MATCH_1}")
    elseif(ORIGINAL_NAME MATCHES "^ImGui(.+)$")
        set(alias_suffix "${CMAKE_MATCH_1}")
    elseif(ORIGINAL_NAME MATCHES "^Im(.+)$")
        set(alias_suffix "${CMAKE_MATCH_1}")
    elseif(ORIGINAL_NAME MATCHES "^IM_(.+)$")
        set(alias_suffix "${CMAKE_MATCH_1}")
    else()
        set(alias_suffix "${ORIGINAL_NAME}")
    endif()

    set(${OUTPUT_VARIABLE} "${alias_suffix}" PARENT_SCOPE)
endfunction()

function(generate_cimgui_constant_aliases HEADER_PATH ALIAS_PREFIX)
    file(APPEND "${RL_ALIAS_HEADER_PATH}"
        "// cimgui constant aliases (${ALIAS_PREFIX}*)\n")

    set(generated_aliases "")
    file(STRINGS "${HEADER_PATH}" macro_lines
        REGEX "^[ \t]*#define[ \t]+(Im[A-Za-z0-9_]+|IM_[A-Z0-9_]+)([ \t]|$)")
    foreach(line IN LISTS macro_lines)
        string(REGEX MATCH
            "#define[ \t]+(Im[A-Za-z0-9_]*|IM_[A-Z0-9_]*)" _ "${line}")
        set(constant_name "${CMAKE_MATCH_1}")
        get_cimgui_alias_suffix("${constant_name}" constant_suffix)
        set(alias_name "${ALIAS_PREFIX}${constant_suffix}")
        list(FIND generated_aliases "${alias_name}" existing_alias_index)
        if(NOT existing_alias_index EQUAL -1)
            continue()
        endif()
        list(APPEND generated_aliases "${alias_name}")
        if(NOT alias_name STREQUAL constant_name)
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "#if defined(${constant_name})\n"
                "#define ${alias_name} ${constant_name}\n"
                "#endif\n")
        endif()
    endforeach()

    file(STRINGS "${HEADER_PATH}" enum_lines
        REGEX "^[ \t]+Im[A-Za-z0-9_]+[ \t]*(=[^,]+)?[,]")
    foreach(line IN LISTS enum_lines)
        string(REGEX MATCH "^[ \t]+(Im[A-Za-z0-9_]*)" _ "${line}")
        set(constant_name "${CMAKE_MATCH_1}")
        get_cimgui_alias_suffix("${constant_name}" constant_suffix)
        set(alias_name "${ALIAS_PREFIX}${constant_suffix}")
        list(FIND generated_aliases "${alias_name}" existing_alias_index)
        if(NOT existing_alias_index EQUAL -1)
            continue()
        endif()
        list(APPEND generated_aliases "${alias_name}")
        if(NOT alias_name STREQUAL constant_name)
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "#define ${alias_name} ${constant_name}\n")
        endif()
    endforeach()

    file(APPEND "${RL_ALIAS_HEADER_PATH}" "\n")
endfunction()

function(split_c_arguments ARGUMENTS OUTPUT_VARIABLE)
    set(arguments_list "")
    set(current_argument "")
    set(parenthesis_depth 0)
    set(bracket_depth 0)
    string(LENGTH "${ARGUMENTS}" arguments_length)
    if(arguments_length GREATER 0)
        math(EXPR arguments_last_index "${arguments_length} - 1")
        foreach(character_index RANGE 0 ${arguments_last_index})
            string(SUBSTRING "${ARGUMENTS}" ${character_index} 1 character)
            if(character STREQUAL "(")
                math(EXPR parenthesis_depth "${parenthesis_depth} + 1")
            elseif(character STREQUAL ")")
                math(EXPR parenthesis_depth "${parenthesis_depth} - 1")
            elseif(character STREQUAL "[")
                math(EXPR bracket_depth "${bracket_depth} + 1")
            elseif(character STREQUAL "]")
                math(EXPR bracket_depth "${bracket_depth} - 1")
            endif()

            if(character STREQUAL "," AND
               parenthesis_depth EQUAL 0 AND bracket_depth EQUAL 0)
                string(STRIP "${current_argument}" current_argument)
                list(APPEND arguments_list "${current_argument}")
                set(current_argument "")
            else()
                string(APPEND current_argument "${character}")
            endif()
        endforeach()
    endif()

    string(STRIP "${current_argument}" current_argument)
    if(NOT current_argument STREQUAL "")
        list(APPEND arguments_list "${current_argument}")
    endif()
    set(${OUTPUT_VARIABLE} "${arguments_list}" PARENT_SCOPE)
endfunction()

function(get_c_argument_name ARGUMENT OUTPUT_VARIABLE)
    if(ARGUMENT MATCHES "\\(\\*[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*\\)")
        set(argument_name "${CMAKE_MATCH_1}")
    else()
        string(REGEX REPLACE "[ \t]*\\[[^]]*\\][ \t]*$" "" argument_without_array "${ARGUMENT}")
        string(REGEX MATCH "([A-Za-z_][A-Za-z0-9_]*)[ \t]*$" argument_name "${argument_without_array}")
    endif()

    if(argument_name STREQUAL "")
        message(FATAL_ERROR "Could not parse cimgui argument name from '${ARGUMENT}'")
    endif()
    set(${OUTPUT_VARIABLE} "${argument_name}" PARENT_SCOPE)
endfunction()

function(generate_cimgui_api_aliases HEADER_PATH ALIAS_PREFIX)
    file(APPEND "${RL_ALIAS_HEADER_PATH}"
        "// cimgui API aliases (${ALIAS_PREFIX}*)\n")

    file(STRINGS "${HEADER_PATH}" api_lines
        REGEX "^[ \t]*CIMGUI_API[ \t]+.*\\);")
    set(generated_aliases "")
    foreach(line IN LISTS api_lines)
        string(FIND "${line}" "(" argument_list_start)
        if(argument_list_start EQUAL -1)
            message(WARNING "Could not parse cimgui API declaration: ${line}")
            continue()
        endif()

        string(SUBSTRING "${line}" 0 ${argument_list_start} declaration)
        string(REGEX MATCH "([A-Za-z_][A-Za-z0-9_]*)[ \t]*$" function_name "${declaration}")
        if(NOT function_name)
            message(WARNING "Could not parse cimgui API declaration: ${line}")
            continue()
        endif()

        if(function_name STREQUAL "igBegin")
            set(function_suffix "BeginWindow")
        elseif(function_name STREQUAL "igEnd")
            set(function_suffix "EndWindow")
        else()
            get_cimgui_alias_suffix("${function_name}" function_suffix)
        endif()
        set(alias_name "${ALIAS_PREFIX}${function_suffix}")
        list(FIND generated_aliases "${alias_name}" existing_alias_index)
        if(NOT existing_alias_index EQUAL -1)
            message(FATAL_ERROR
                "cimgui alias collision while generating ${alias_name} from ${function_name}")
        endif()
        list(APPEND generated_aliases "${alias_name}")

        set(api_condition "")
        if(function_name MATCHES "0$")
            set(api_condition "CIMGUI_VARGS0")
        elseif(function_name MATCHES "^ImGuiFreeType_")
            set(api_condition "IMGUI_ENABLE_FREETYPE")
        elseif(function_name MATCHES "^ImGuiPlatformIO_Set_")
            set(api_condition "IMGUI_HAS_DOCK")
        endif()
        if(NOT api_condition STREQUAL "")
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "#if defined(${api_condition})\n")
        endif()

        if(RL_ALIAS_MODE STREQUAL "DEFINE")
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "#define ${alias_name} ${function_name}\n")
            if(NOT api_condition STREQUAL "")
                file(APPEND "${RL_ALIAS_HEADER_PATH}" "#endif\n")
            endif()
            continue()
        endif()

        string(REGEX REPLACE "[ \t]*${function_name}[ \t]*$" "" return_type "${declaration}")
        string(REGEX REPLACE "^[ \t]*CIMGUI_API[ \t]+" "" return_type "${return_type}")
        string(STRIP "${return_type}" return_type)

        math(EXPR arguments_start "${argument_list_start} + 1")
        string(SUBSTRING "${line}" ${arguments_start} -1 arguments)
        string(REGEX REPLACE "\\)[ \t]*;[ \t]*$" "" arguments "${arguments}")
        string(STRIP "${arguments}" arguments)

        if(arguments MATCHES "\\.\\.\\.")
            # C99 cannot forward an arbitrary variadic argument list without a
            # corresponding va_list entry point.
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "#define ${alias_name} ${function_name}\n")
            if(NOT api_condition STREQUAL "")
                file(APPEND "${RL_ALIAS_HEADER_PATH}" "#endif\n")
            endif()
            continue()
        endif()

        set(call_arguments "")
        if(NOT arguments STREQUAL "void" AND NOT arguments STREQUAL "")
            split_c_arguments("${arguments}" split_arguments)
            foreach(argument IN LISTS split_arguments)
                get_c_argument_name("${argument}" argument_name)
                if(call_arguments STREQUAL "")
                    set(call_arguments "${argument_name}")
                else()
                    string(APPEND call_arguments ", ${argument_name}")
                endif()
            endforeach()
        else()
            set(arguments "void")
        endif()

        file(APPEND "${RL_ALIAS_HEADER_PATH}"
            "static inline ${return_type} ${alias_name}(${arguments})\n"
            "{\n")
        if(return_type STREQUAL "void")
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "    ${function_name}(${call_arguments});\n")
        else()
            file(APPEND "${RL_ALIAS_HEADER_PATH}"
                "    return ${function_name}(${call_arguments});\n")
        endif()
        file(APPEND "${RL_ALIAS_HEADER_PATH}" "}\n\n")
        if(NOT api_condition STREQUAL "")
            file(APPEND "${RL_ALIAS_HEADER_PATH}" "#endif\n")
        endif()
    endforeach()

    file(APPEND "${RL_ALIAS_HEADER_PATH}" "\n")
endfunction()

generate_constant_aliases("raylib" "${RAYLIB_HEADER_PATH}" "${RAYLIB_ALIAS_PREFIX}" TRUE)
generate_api_aliases("raylib" "${RAYLIB_HEADER_PATH}" "${RAYLIB_ALIAS_PREFIX}"
    "^[ \t]*RLAPI[ \t]+.*\\);")
generate_constant_aliases("rlgl" "${RLGL_HEADER_PATH}" "${RLGL_ALIAS_PREFIX}" TRUE)
generate_api_aliases("rlgl" "${RLGL_HEADER_PATH}" "${RLGL_ALIAS_PREFIX}"
    "^[ \t]*RLAPI[ \t]+.*\\);")
file(APPEND "${RL_ALIAS_HEADER_PATH}" "#endif // _RL_ALIAS_H\n")
message(STATUS "Raylib alias file generated: ${RL_ALIAS_HEADER_PATH}")

if(DEFINED IM_ALIAS_HEADER_PATH)
    set(RL_ALIAS_HEADER_PATH "${IM_ALIAS_HEADER_PATH}")
    get_filename_component(IM_ALIAS_HEADER_DIR "${IM_ALIAS_HEADER_PATH}" DIRECTORY)
    file(MAKE_DIRECTORY "${IM_ALIAS_HEADER_DIR}")
    file(WRITE "${IM_ALIAS_HEADER_PATH}" "// Auto-generated ImGui alias file\n\n")
    file(APPEND "${IM_ALIAS_HEADER_PATH}" "#ifndef _IM_ALIAS_H\n")
    file(APPEND "${IM_ALIAS_HEADER_PATH}" "#define _IM_ALIAS_H\n")
    file(APPEND "${IM_ALIAS_HEADER_PATH}" "#include <cimgui.h>\n")
    file(APPEND "${IM_ALIAS_HEADER_PATH}" "#include <rlImGui.h>\n\n")

    generate_api_aliases("rlImGui" "${RLIMGUI_HEADER_PATH}" "${RLIMGUI_ALIAS_PREFIX}"
        "^[ \t]*(RLIMGUIAPI[ \t]+)?.*rlImGui[A-Za-z0-9_]*[ \t]*\\(.*\\);")
    generate_cimgui_constant_aliases("${CIMGUI_HEADER_PATH}" "${CIMGUI_ALIAS_PREFIX}")
    generate_cimgui_api_aliases("${CIMGUI_HEADER_PATH}" "${CIMGUI_ALIAS_PREFIX}")

    file(APPEND "${IM_ALIAS_HEADER_PATH}" "#endif // _IM_ALIAS_H\n")
    message(STATUS "ImGui alias file generated: ${IM_ALIAS_HEADER_PATH}")
endif()
