#
# cmake/Common.cmake
# Copyright (C) 2012, Dominique Lasserre <lasserre.d@gmail.com>
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

  set(list_string "")
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
  cmake_parse_arguments(ARGS "" "" "ICON;SIZES;PNG_NAME" ${ARGN})

  set(png_list)
  if(ARGS_ICON)
    if(ARGS_PNG_NAME)
      find_program(CONVERT convert)

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
            ${CONVERT}
          ARGS
            -background none -resize "${size}x${size}" "${ARGS_ICON}" "${iconpath}"
        )
        list(APPEND png_list "${iconpath}")
        install(FILES "${iconpath}" DESTINATION "share/${tmppath}")
      endforeach()
    endif()
  endif()

  set(${output} "${png_list}" PARENT_SCOPE)
endfunction()
