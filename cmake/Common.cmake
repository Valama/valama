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
