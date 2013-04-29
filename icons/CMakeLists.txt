#
# icons/CMakeLists.txt
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

include("${CMAKE_SOURCE_DIR}/cmake/Common.cmake")

# Generate usable application icons.
set(sizeslist "24" "32" "48" "64" "72" "96" "128" "256")
convert_svg_to_png(png_list
  ICON
    "${CMAKE_CURRENT_SOURCE_DIR}/V4_logo.svg"
  SIZES
    ${sizeslist}
  PNG_NAME
    "valama"
)
add_custom_target(icons
  ALL
  DEPENDS
    ${png_list}
  COMMENT
    "Generate application icons." VERBATIM
)

# Generate logo with text.
set(sizeslist "128")
convert_svg_to_png(textlogo
  ICON
    "${CMAKE_CURRENT_SOURCE_DIR}/V4.svg"
  SIZES
    ${sizeslist}
  PNG_NAME
    "valama-text"
  DESTINATION
    "${datadir}"
)
add_custom_target(icons_text
  ALL
  DEPENDS
    ${textlogo}
  COMMENT
    "Generate text logo." VERBATIM
)


# Install application icon.
if(CONVERT)
  install(
    FILES
      "${CMAKE_CURRENT_BINARY_DIR}/icons/hicolor/32x32/apps/valama.png"
    DESTINATION
      "${pixrootdir}"
  )
endif()
