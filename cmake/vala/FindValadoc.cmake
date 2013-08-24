#
# cmake/vala/FindValadocs.cmake
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
# Add find_package handler for valadoc.
##

# Search for the valac executable in the usual system paths.
find_program(VALADOC_EXECUTABLE "valadoc")
mark_as_advanced(VALADOC_EXECUTABLE)

# Determine the valadoc version
if(VALADOC_EXECUTABLE)
  execute_process(
    COMMAND
      "${VALADOC_EXECUTABLE}" "--version"
    OUTPUT_VARIABLE
      VALADOC_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  string(REPLACE "Valadoc " "" VALADOC_VERSION "${VALADOC_VERSION}")
endif()

# Add find_package handler for valadoc.
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Valadoc
  REQUIRED_VARS
    VALADOC_EXECUTABLE
  VERSION_VAR
    VALADOC_VERSION
)
