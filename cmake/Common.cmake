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
# Convert svg to png and set up installation places. rsvg-convert or
# imagemagick (with svg support) is required.
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
      find_program(CONVERT rsvg-convert)
      if(NOT CONVERT)
        find_program(CONVERT_IMG convert)
      endif()
      if(CONVERT OR CONVERT_IMG)
        if(NOT datarootdir)
          set(datarootdir "share")
        endif()

        foreach(size ${ARGS_SIZES})
          set(tmppath "icons/hicolor/${size}x${size}/apps")
          set(icondir "${CMAKE_CURRENT_BINARY_DIR}/${tmppath}")
          set(iconpath "${icondir}/${ARGS_PNG_NAME}.png")
          if(CONVERT)
            add_custom_command(
              OUTPUT
                "${iconpath}"
              COMMAND
                "${CMAKE_COMMAND}" -E make_directory "${icondir}"
              COMMAND
                "${CONVERT}" "--background-color" "none" "--width" "${size}" "--height" "${size}" "${ARGS_ICON}" "--output" "${iconpath}"
              DEPENDS
                "${ARGS_ICON}"
              VERBATIM
            )
          else()
            add_custom_command(
              OUTPUT
                "${iconpath}"
              COMMAND
                "${CMAKE_COMMAND}" -E make_directory "${icondir}"
              COMMAND
                "${CONVERT_IMG}" "-background" "none" "-resize" "${size}x${size}" "${ARGS_ICON}" "${iconpath}"
              DEPENDS
                "${ARGS_ICON}"
              VERBATIM
            )
          endif()
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
# Install/verify gsettings files and compile schemas.
#
# Depends on cmake/GlibCompileSchema.cmake.in (for compiling) and
# cmake/GlibCompileSchema_verify.cmake.in (for verifying, only wth local
# option)
#
# Usage:
#
# LOCAL
#   If set compile gsettings schemas locally (in
#   ${CMAKE_BINARY_DIR}/glib-2.0/schemas) directory). Add this directory to
#   your XDG_DATA_DIRS variable.
#
# GSETTINGSDIR
#   Directory where to install gsettings schemas. Default is:
#   share/glib-2.0/schemas
#
# FILES
#   List of gsettings schema files to install / compiile.
#
#
# Simple example:
#
#   gsettings_install(
#     LOCAL
#     GSETTINGSDIR
#       share/glib-2.0/schemas
#     FILES
#       "data/app.foobar.gschema.xml"
#   )
#
function(gsettings_install)
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "LOCAL" "GSETTINGSDIR" "FILES" ${ARGN})
  find_program(GLIBCOMPILESCHEMA "glib-compile-schemas" REQUIRED)

  if(NOT "" STREQUAL "${ARGS_FILES}")
    if(ARGS_LOCAL)
      set(GSETTINGSDIR "glib-2.0/schemas")
      configure_file(
        "${CMAKE_SOURCE_DIR}/cmake/GlibCompileSchema.cmake.in"
        "${CMAKE_BINARY_DIR}/GlibCompileSchema_local.cmake"
        @ONLY
      )
      configure_file(
        "${CMAKE_SOURCE_DIR}/cmake/GlibCompileSchema_verify.cmake.in"
        "${CMAKE_BINARY_DIR}/GlibCompileSchema_verify.cmake"
        COPYONLY
      )
      set(gfiles_copied)
      foreach(gfile ${ARGS_FILES})
        if(NOT IS_ABSOLUTE "${gfile}")
          set(gfile "${CMAKE_CURRENT_SOURCE_DIR}/${gfile}")
        endif()
        get_filename_component(filename "${gfile}" NAME)
        set(gfile_copied "${CMAKE_CURRENT_BINARY_DIR}/glib-2.0/schemas/${filename}")
        add_custom_command(
            OUTPUT
              "${gfile_copied}"
            COMMAND
              "${CMAKE_COMMAND}" -D "GLIBCOMPILESCHEMA:FILEPATH=${GLIBCOMPILESCHEMA}"
                                 -D "GLIB_SCHEMAFILE:FILEPATH=${gfile}"
                                 -P "${CMAKE_BINARY_DIR}/GlibCompileSchema_verify.cmake"
            COMMAND
              "${CMAKE_COMMAND}" -E copy_if_different "${gfile}" "${gfile_copied}"
            DEPENDS
              "${gfile}"
            COMMENT
              "Install and verify gsettings schemas locally..."
            VERBATIM
        )
        list(APPEND gfiles_copied "${gfile_copied}")
      endforeach()
      add_custom_command(
          OUTPUT
            "glib-2.0/schemas/gschemas.compiled"
          COMMAND
            "${CMAKE_COMMAND}" -P "${CMAKE_BINARY_DIR}/GlibCompileSchema_local.cmake"
          DEPENDS
            ${gfiles_copied}
          COMMENT
            "Compile gsettings schemas..."
          VERBATIM
      )
      add_custom_target("gsettings_${project_name_lower}"
        DEPENDS
          "glib-2.0/schemas/gschemas.compiled"
      )
      add_dependencies("${project_name_lower}" "gsettings_${project_name_lower}")
    endif()

    if(NOT ARGS_GSETTINGSDIR)
      set(ARGS_GSETTINGSDIR "share/glib-2.0/schemas")
    endif()
    foreach(gfile ${ARGS_FILES})
      install(FILES "${gfile}" DESTINATION "${ARGS_GSETTINGSDIR}")
    endforeach()

    if(POSTINSTALL_HOOK AND "$ENV{DESTDIR}" STREQUAL "")
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


##
# Recursively copy directory content.
#
# Usage:
#
# TARGET
#   Name of CMake target. Default is 'copy_dirs'.
#
# BASEDIR
#   Name of base directory to build relative paths compared  to TARGETDIR.
#   Default is ${CMAKE_CURRENT_SOURCE_DIR}.
#
# TARGETDIR
#   Name of base directory where to copy files to. Default is
#   ${CMAKE_CURRENT_BINARY_DIR}.
#
# DIRS
#   List of directories (or files) to recursively copy.
#
#
# Simple example:
#
#     copy_dirs(
#       TARGET
#         "custom_target_name
#       BASEDIR
#         "${CMAKE_CURRENT_SOURCE_DIR}/foo"
#       TARGETDIR
#         "${CMAKE_CURRENT_BINARY_DIR}/bar"
#       DIRS
#         "blub̈́*"
#         "/foobar/bar"
#     )
#     # Copy ${}/foo/blub* and /foobar/bar to ${}/bar (= ${}/bar/blub*) and
#     #                                                  ${}/bar/foobar/bar)
#     add_custom_target("foobar"
#       ALL
#       DEPENDS
#         "custom_target_name"
#       COMMENT "Copy some files"
#     )
#
function(copy_dirs)
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "" "TARGET;BASEDIR;TARGETDIR" "DIRS" ${ARGN})

  if(NOT ARGS_BASEDIR)
    set(ARGS_BASEDIR "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  if(NOT ARGS_TARGET)
    set(ARGS_TARGET "copy_dirs")
  endif()
  if(NOT ARGS_TARGETDIR)
    set(ARGS_TARGETDIR "${CMAKE_CURRENT_BINARY_DIR}")
  endif()

  set(copyfiles)
  foreach(globexpr ${ARGS_DIRS})
    file(GLOB tmpdirs ${globexpr})
    if(tmpdirs)
      foreach(tmpdir ${tmpdirs})
        get_files_recursively(files "${tmpdir}")
        list(APPEND copyfiles ${files})
      endforeach()
    else()
      get_files_recursively(files "${globexpr}")
      list(APPEND copyfiles ${files})
    endif()
  endforeach()

  set(copyfiles_d)
  foreach(copyfile ${copyfiles})
    file(RELATIVE_PATH copyfile_d "${ARGS_BASEDIR}" "${copyfile}")
    set(copyfile_d "${ARGS_TARGETDIR}/${copyfile_d}")
    add_custom_command(
      OUTPUT
        "${copyfile_d}"
      COMMAND
        "${CMAKE_COMMAND}" -E copy_if_different "${copyfile}" "${copyfile_d}"
      DEPENDS
        "${copyfile}"
      VERBATIM
    )
    list(APPEND copyfiles_d "${copyfile_d}")
  endforeach()

  add_custom_target("${ARGS_TARGET}"
    DEPENDS
      ${copyfiles_d}
    #COMMENT "Copy data files."
  )
endfunction()


##
# Recursively get list of files.
#
# From refaim on stackoverflow: http://stackoverflow.com/a/7788165/770468
#
# Usage:
# The first parameter is set to list of files. The second one is the path of
# current directory.
#
#
# Simple example:
#
#   # Set ${files} to all files in foo/ directory.
#   get_files_recursively(files "foo")
#
macro(get_files_recursively result curdir)
  file(GLOB children RELATIVE "${curdir}" "${curdir}/*")
  set(files)
  foreach(child ${children})
    if(IS_DIRECTORY "${curdir}/${child}")
      get_files_recursively(subfiles "${curdir}")
      list(APPEND files ${subfiles})
    else()
      list(APPEND files "${curdir}/${child}")
    endif()
  endforeach()
  set(${result} ${files})
endmacro()


##
# Computes the realtionship between two version strings.  A version
# string is a number delineated by '.'s such as 1.3.2 and 0.99.9.1.
# You can feed version strings with different number of dot versions,
# and the shorter version number will be padded with zeros: 9.2 <
# 9.2.1 will actually compare 9.2.0 < 9.2.1.
#
# Input: a_in - value, not variable
#        b_in - value, not variable
#        result_out - variable with value:
#                         -1 : a_in <  b_in
#                          0 : a_in == b_in
#                          1 : a_in >  b_in
#
# Written by James Bigler.
# http://www.cmake.org/Wiki/CMakeCompareVersionStrings (2013/09/29)
#
macro(compare_version_strings a_in b_in result_out)
  # Since SEPARATE_ARGUMENTS using ' ' as the separation token,
  # replace '.' with ' ' to allow easy tokenization of the string.
  string(REPLACE "." " " a ${a_in})
  string(REPLACE "." " " b ${b_in})
  separate_arguments(a)
  separate_arguments(b)

  # Check the size of each list to see if they are equal.
  list(LENGTH a a_length)
  list(LENGTH b b_length)

  # Pad the shorter list with zeros.

  # Note that range needs to be one less than the length as the for
  # loop is inclusive (silly CMake).
  if(a_length LESS b_length)
    # a is shorter
    set(shorter a)
    math(EXPR range "${b_length} - 1")
    math(EXPR pad_range "${b_length} - ${a_length} - 1")
  else()
    # b is shorter
    set(shorter b)
    math(EXPR range "${a_length} - 1")
    math(EXPR pad_range "${a_length} - ${b_length} - 1")
  endif()

  # PAD out if we need to
  if(NOT pad_range LESS 0)
    foreach(pad RANGE ${pad_range})
      # Since shorter is an alias for b, we need to get to it by by dereferencing shorter.
      list(APPEND ${shorter} 0)
    endforeach()
  endif()

  set(result 0)
  foreach(index RANGE ${range})
    if(result EQUAL 0)
      # Only continue to compare things as long as they are equal
      list(GET a ${index} a_version)
      list(GET b ${index} b_version)
      # LESS
      if(a_version LESS b_version)
        set(result -1)
      endif()
      # GREATER
      if(a_version GREATER b_version)
        set(result 1)
      endif()
    endif()
  endforeach()

  # Copy out the return result
  set(${result_out} ${result})
endmacro()
