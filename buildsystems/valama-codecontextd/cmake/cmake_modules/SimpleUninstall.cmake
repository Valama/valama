#
# cmake/SimpleUninstall.cmake
# Copyright (C) 2013, Valama development team
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
#
# Slightly modified version from: http://www.cmake.org/Wiki/CMake_FAQ
#

if(NOT EXISTS "${CMAKE_BINARY_DIR}/install_manifest.txt")
  message(FATAL_ERROR "Cannot find install manifest: "
                      "\"${CMAKE_BINARY_DIR}/install_manifest.txt\"")
endif()

file(READ "${CMAKE_BINARY_DIR}/install_manifest.txt" files)
string(REGEX REPLACE "\n" ";" files "${files}")

cmake_policy(PUSH)
# Ignore empty list elements. 
cmake_policy(SET CMP0007 OLD)
list(REVERSE files)
cmake_policy(POP)

foreach(file ${files})
  message(STATUS "Uninstalling \"$ENV{DESTDIR}${file}\"")
  if(EXISTS "$ENV{DESTDIR}${file}")
    execute_process(
      COMMAND
        "${CMAKE_COMMAND}" -E remove "$ENV{DESTDIR}${file}"
      OUTPUT_VARIABLE
        rm_out
      RESULT_VARIABLE
        rm_retval
    )
    if(NOT ${rm_retval} EQUAL 0)
      message(FATAL_ERROR "Problem when removing \"$ENV{DESTDIR}${file}\"")
    endif()
  else()
    message(STATUS "File \"$ENV{DESTDIR}${file}\" does not exist.")
  endif()
endforeach()

if(NOT "$ENV{DESTDIR}" AND POSTREMOVE_HOOK)
  if (GSETTINGSDIR)
    set(compile_schema_file "${CMAKE_BINARY_DIR}/GlibCompileSchema_uninstall.cmake")
    if(NOT EXISTS "${compile_schema_file}")
      if(NOT CUSTOM_SOURCE_DIR)
        set(CUSTOM_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
      endif()
      configure_file(
        "${CUSTOM_SOURCE_DIR}/cmake/GlibCompileSchema.cmake.in"
        "${compile_schema_file}"
        @ONLY
      )
    endif()
  endif()
  execute_process(
    COMMAND
    "${CMAKE_COMMAND}" -P "${compile_schema_file}"
  )
endif()