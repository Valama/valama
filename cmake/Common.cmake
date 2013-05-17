#
# cmake/Common.cmake
# Copyright (C) 2012, 2013, Valama development team
#
# Valama is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Valama is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.
#
##
# The base_list_to_delimited_string function transforms a list into a delimited
# string.
# This function is based on the basis_list_to_delimited_string in
# CommonTools.cmake by the Build system And Software Implementation Standard
# (BASIS) project by the University of Pennsylvania (Penn).
#
# Usage:
#
# The first parameter is set to transformed list.
#
# DELIM
#   A string which will be the delimiter between all list elements.
#
# BASE_LIST
#   The list which will be transformed to a single string.
#
#
# Simple example:
#
#   set(packages "abc" "def" "fhi" "jkl" "mno")
#   base_list_to_delimited_string(transformed_list
#     DELIM
#       "||"
#     BASE_LIST
#       ${packages}
#   )
#   message("show it:${transformed_list}")
#   >> show it:abc||def||fhi||jkl||mno
#
function(base_list_to_delimited_string output)
  cmake_parse_arguments(ARGS "" "" "DELIM;BASE_LIST" ${ARGN})

  set(list_string)
  foreach(element ${ARGS_BASE_LIST})
    if(list_string)
      set(list_string "${list_string}${ARGS_DELIM}")
    endif()
    if(element MATCHES "${ARGS_DELIM}")
      set(list_string "${list_string}\"${element}\"")
    else()
      set(list_string "${list_string}${element}")
    endif()
  endforeach()

  set("${output}" "${list_string}" PARENT_SCOPE)
endfunction()


##
# Convert svg to png and set up installation places. convert tool from
# imagemagick is required.
#
# Usage:
# The first parameter is set to all png files. Add them later to a custom
# target. Generated directories are:
#   ${prefix}/share/icons/hicolor/${size}x${size}/apps/${png_name}.png
#
# ICON
#   svg icon path
#
# SIZES
#   List of all supported sizes.
#
# PNG_NAME
#   Name of png file (without suffix) which is the target file name.
#
# DESTINATION
#   Directory where to install all generated files to (plain).
#
#
# Simple example:
#
#   set(sizes 42 43 44)
#   convert_svg_to_png(png_files
#     ICON
#       my_really_cool_icon.svg
#     SIZES
#       "${sizes}"
#     PNG_NAME
#       freshy
#   )
#   add_custom_target(my_target_name ALL DEPENDS ${png_files})
#
#   # This will build and install my_really_cool_icon.svg to:
#   #   /usr/share/icons/hicolor/42x42/apps/freshy.png
#   #   /usr/share/icons/hicolor/43x43/apps/freshy.png
#   #   /usr/share/icons/hicolor/44x44/apps/freshy.png
#
function(convert_svg_to_png output)
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "" "DESTINATION" "ICON;SIZES;PNG_NAME" ${ARGN})

  set(png_list)
  if(ARGS_ICON)
    if(ARGS_PNG_NAME)
      find_program(CONVERT convert)
      if(CONVERT)
        if(NOT datarootdir)
          set(datarootdir "share")
        endif()

        foreach(size ${ARGS_SIZES})
          set(tmppath "icons/hicolor/${size}x${size}/apps")
          set(iconpath "${CMAKE_CURRENT_BINARY_DIR}/${tmppath}/${ARGS_PNG_NAME}.png")
          execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/${tmppath}")
          add_custom_command(
            OUTPUT
              "${iconpath}"
            DEPENDS
              "${ARGS_ICON}"
            COMMAND
              "${CONVERT}" "-background" "none" "-resize" "${size}x${size}" "${ARGS_ICON}" "${iconpath}"
          )
          list(APPEND png_list "${iconpath}")
          if(ARGS_DESTINATION)
            install(FILES "${iconpath}" DESTINATION "${ARGS_DESTINATION}")
          else()
            install(FILES "${iconpath}" DESTINATION "${datarootdir}/${tmppath}")
          endif()
        endforeach()
      else()
        message(WARNING "Could not find convert program. Don't generate icons.")
      endif()
    endif()
  endif()

  set(${output} "${png_list}" PARENT_SCOPE)
endfunction()


##
# Get formatted date string.
#
# Usage:
# The first parameter is set to output date string.
#
# FORMAT
#   Format string.
#
#
# Simple example:
#
#   datestring(date
#     FORMAT "%B %Y"
#   )
#   # Will print out e.g. "Date: April 2013"
#   message("Date: ${date}")
#
#
macro(datestring output)
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "" "FORMAT" "" ${ARGN})

  if(ARGS_FORMAT)
    set(format "${ARGS_FORMAT}")
  else()
    set(format "${ARGN}")
  endif()

  if(WIN32)
    #FIXME: Needs to be tested. Perhaps wrapping with cmd is needed.
    execute_process(
      COMMAND
        "date" "${format}"
      OUTPUT_VARIABLE
        "${output}"
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  else()
    execute_process(
      COMMAND
      "date" "+${format}"
      OUTPUT_VARIABLE
        "${output}"
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  endif()
endmacro()


##
# Install gsettings file and compile schemas.
#
# Depends on cmake/GlibCompileSchema.cmake.in.
#
# Usage:
# Pass a list of schema files to install and compile.
#
#
# Simple example:
#
#   gsettings_install(
#     LOCAL
#       TRUE
#     GSETTINGSDIR
#       share/glib-2.0/schemas
#     FILES
#       "data/app.foobar.gschema.xml"
#   )
#
function(gsettings_install)
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "" "LOCAL;GSETTINGSDIR" "FILES" ${ARGN})

  if(NOT "" STREQUAL "${ARGS_FILES}")
    if(ARGS_LOCAL)
      set(GSETTINGSDIR "glib-2.0/schemas")
      configure_file(
        "${CMAKE_SOURCE_DIR}/cmake/GlibCompileSchema.cmake.in"
        "${CMAKE_BINARY_DIR}/GlibCompileSchema_local.cmake"
        @ONLY
      )
      foreach(gfile ${ARGS_FILES})
        get_filename_component(filename "${gfile}" NAME)
        add_custom_command(
            COMMAND
              ${CMAKE_COMMAND} -E make_directory "${GSETTINGSDIR}"
            COMMAND
              ${CMAKE_COMMAND} -E copy_if_different
                                      "${gfile}"
                                      "${CMAKE_CURRENT_BINARY_DIR}/glib-2.0/schemas/${filename}"
            OUTPUT
              "${GSETTINGSDIR}"
            COMMENT
              "Install gsettings schemas locally." VERBATIM
        )
      endforeach()
      add_custom_command(
          COMMAND
            ${CMAKE_COMMAND} -P "${CMAKE_BINARY_DIR}/GlibCompileSchema_local.cmake"
          DEPENDS
            "${GSETTINGSDIR}"
          OUTPUT
            "glib-2.0/schemas/gschemas.compiled"
          COMMENT
            "Compile gsettings schemas." VERBATIM
      )
      add_custom_target(gsettings
        ALL
        DEPENDS
          "glib-2.0/schemas/gschemas.compiled"
      )
    endif()

    if(NOT ARGS_GSETTINGSDIR)
      set(ARGS_GSETTINGSDIR "share/glib-2.0/schemas")
    endif()
    foreach(gfile ${ARGS_FILES})
      install(FILES "${gfile}" DESTINATION "${ARGS_GSETTINGSDIR}")
    endforeach()

    if(POSTINSTALL_HOOK AND NOT "$ENV{DESTDIR}")
      if(CMAKE_INSTALL_PREFIX)
        set(install_prefix "${CMAKE_INSTALL_PREFIX}/")
      else()
        set(install_prefix)
      endif()
      set(GSETTINGSDIR "${install_prefix}${ARGS_GSETTINGSDIR}")
      configure_file(
        "${CMAKE_SOURCE_DIR}/cmake/GlibCompileSchema.cmake.in"
        "${CMAKE_BINARY_DIR}/GlibCompileSchema.cmake"
        @ONLY
      )
      install(SCRIPT "${CMAKE_BINARY_DIR}/GlibCompileSchema.cmake")
    endif()
  endif()
endfunction()
