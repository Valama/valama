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

include("${CMAKE_SOURCE_DIR}/cmake/guanako.cmake")
include("${CMAKE_SOURCE_DIR}/cmake/Common.cmake")

cmake_minimum_required(VERSION "2.8")
project("${project_name}" C)
string(TOLOWER "${project_name}" project_name_lower)

# export (sub)project version
set("${project_name}_VERSION" "${${project_name}_VERSION}" CACHE INTERNAL "${project_name} version")

set(CMAKE_INSTALL_PREFIX "/usr")
set(bindir "bin")
set(datarootdir "share")
set(libdir "lib")
set(includedir "include")
set(datadir "${datarootdir}/${project_name_lower}")
set(localedir "${datarootdir}/locale")
set(appdir "${datarootdir}/applications")
set(pixdir "${datarootdir}/pixmaps/${project_name_lower}")
set(docdir "${datadir}/doc")
set(mandir "${datarootdir}/man")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/vala")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")


option(DEBUG "Debug output on console." ON)
option(THREADED "Run multi-threaded." OFF)

if(DEBUG)
  set(debug_opt "-D;DEBUG")
else()
  set(debug_opt "")
endif()
if(NOT THREADED)
  set(threaded_opt "-D;NOT_THREADED")
else()
  set(threaded_opt "")
endif()

find_package(Vala "0.16" REQUIRED)

if(VALA_VERSION STRGREATER "0.17.0")
  list(REMOVE_ITEM required_pkgs "libvala-0.16" )
  set(valashort_ver "0.18")
  set(valac_cond "")
else()
  list(REMOVE_ITEM required_pkgs "libvala-0.18" )
  set(valashort_ver "0.16")
  set(valac_cond "-D;VALA_LESS_0_18")
endif()
set(vapishort_dir "vala-${valashort_ver}/vapi")
set(vapidir "/usr/share/${vapishort_dir}")

set(pc_prefix ${CMAKE_INSTALL_PREFIX})
set(pc_exec_prefix "\${prefix}")
set(pc_libdir "\${exec_prefix}/${libdir}")
set(pc_includedir "\${prefix}/${includedir}")
set(pc_datarootdir "\${prefix}/${datarootdir}")
set(pc_vapidir "\${datarootdir}/${vapishort_dir}")
set(pc_version "${${project_name}_VERSION}")
base_list_to_delimited_string(pc_requirements
  DELIM " "
  BASE_LIST ${required_pkgs}
)
configure_file("${project_name_lower}.pc.in" "${project_name_lower}.pc")

base_list_to_delimited_string(deps_requirements
  DELIM "\n"
  BASE_LIST ${required_pkgs}
)
configure_file("${project_name_lower}.deps.in" "${project_name_lower}.deps")

set(srcfiles "${CMAKE_CURRENT_SOURCE_DIR}/*.vala")
set(default_vala_flags
  "--thread"
  "-H" "${project_name_lower}.h"
  "--gir" "${project_name}-${${project_name}_VERSION}.gir"
  "--library" "${project_name_lower}"
  "--target-glib" "2.32"  # enable this to use new(tm) thread syntax
  ${debug_opt}
  ${threaded_opt}
  ${valac_cond}
)
include(ValaPkgs)
vala_pkgs(VALA_C
  PACKAGES
    ${required_pkgs}
  OPTIONAL
    ${optional_pkgs}
  SRCFILES
    ${srcfiles}
  VAPIS
    "config.vapi"
  OPTIONS
    ${default_vala_flags}
)
if(NOT PkgConfig_FOUND)
  find_package(PkgConfig)
endif()
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
add_definitions(${GTHREAD_CFLAGS})
link_libraries(${GTHREAD_LIBRARIES})

add_library("${project_name_lower}" SHARED ${VALA_C})
set_target_properties("${project_name_lower}" PROPERTIES
    VERSION "${${project_name}_VERSION}"
    SOVERSION "${soversion}"
)

# Set common C-macros.
add_definitions(-DPACKAGE_NAME="${project_name}")
add_definitions(-DPACKAGE_VERSION="${${project_name}_VERSION}")
add_definitions(-DGETTEXT_PACKAGE="${project_name_lower}")
add_definitions(-DPACKAGE_DATA_DIR="${CMAKE_INSTALL_PREFIX}/${datadir}")
add_definitions(-DLOCALE_DIR="${CMAKE_INSTALL_PREFIX}/${localedir}")
add_definitions(-DPIXMAP_DIR="${CMAKE_INSTALL_PREFIX}/${pixdir}")
add_definitions(-DVALA_VERSION="${valashort_ver}")

# Set custom C-macros.
add_definitions(-DVALA_DATA_DIR="${vala_datadir}")

install(TARGETS "${project_name_lower}" DESTINATION "${libdir}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.pc" DESTINATION "lib/pkgconfig")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.h" DESTINATION "${includedir}")
set(vapi_files "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.deps" "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.vapi")
install(FILES ${vapi_files} DESTINATION "${vapidir}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name}-${${project_name}_VERSION}.gir" DESTINATION "${datarootdir}/gir-1.0")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/syntax" DESTINATION "${datarootdir}/valama")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/${project_name_lower}.lang" DESTINATION "${datarootdir}/gtksourceview-3.0/language-specs")

# vim: set ai ts=2 sts=2 et sw=2
