#
# guanako/CMakeLists.txt
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

include(${CMAKE_SOURCE_DIR}/cmake/guanako.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/Common.cmake)

cmake_minimum_required(VERSION 2.8)
project("guanako" C)

set(CMAKE_INSTALL_PREFIX "/usr")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/vala")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")


find_package(Vala "0.16" REQUIRED)
# Little fix to ignore a wrong libvala version.
if(VALA_VERSION STRGREATER "0.17.0")
  list(REMOVE_ITEM guanako_required_pkgs "libvala-0.16" )
  set(vala_version_short "0.18")
else()
  list(REMOVE_ITEM guanako_required_pkgs "libvala-0.18" )
  set(vala_version_short "0.16")
endif()

set(prefix ${CMAKE_INSTALL_PREFIX})
set(exec_prefix "\${prefix}")
set(libdir "\${exec_prefix}/lib")
set(includedir "\${prefix}/include")
set(datarootdir "\${prefix}/share")
set(vapidir "\${datarootdir}/vala-${vala_version_short}/vapi")
set(version "${guanako_version}")
base_list_to_delimited_string(guanako_pc_requirements
  DELIM
    " "
  BASE_LIST
    ${guanako_required_pkgs}
)
configure_file("guanako.pc.in" "guanako.pc")

base_list_to_delimited_string(guanako_deps_requirements
  DELIM
    "\n"
  BASE_LIST
    ${guanako_required_pkgs}
)
configure_file("guanako.deps.in" "guanako.deps")

set(srcfiles "${CMAKE_CURRENT_SOURCE_DIR}/*.vala")
include(ValaPkgs)
vala_pkgs(VALA_C
  PACKAGES
    ${guanako_required_pkgs}
  OPTIONAL
    ${guanako_optional_pkgs}
  SRCFILES
    ${srcfiles}
  OPTIONS
    --thread
    -H guanako.h
    --gir "Guanako-${guanako_version}.gir"
    --library guanako
    "-D;DEBUG"
    ${valac_cond}
)
if(NOT PkgConfig_FOUND)
  find_package(PkgConfig)
endif()
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
add_definitions(${GTHREAD_CFLAGS})
link_libraries(${GTHREAD_LIBRARIES})

add_library(guanako SHARED ${VALA_C})
set_target_properties(guanako PROPERTIES
    VERSION "${guanako_version}"
    SOVERSION "${guanako_soversion}")


install(TARGETS guanako DESTINATION "lib")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/guanako.pc" DESTINATION "lib/pkgconfig")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/guanako.h" DESTINATION "include")
set(vapi_files "${CMAKE_CURRENT_BINARY_DIR}/guanako.deps" "${CMAKE_CURRENT_BINARY_DIR}/guanako.vapi")
install(FILES ${vapi_files} DESTINATION "${prefix}/share/vala-${vala_version_short}/vapi")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/Guanako-${guanako_version}.gir" DESTINATION "share/gir-1.0")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/syntax" DESTINATION "share/valama")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/guanako.lang" DESTINATION "share/gtksourceview-3.0/language-specs")

# vim: set ai ts=2 sts=2 et sw=2
