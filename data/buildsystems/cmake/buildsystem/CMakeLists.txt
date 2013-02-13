#
# CMakeLists.txt
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

include("${CMAKE_SOURCE_DIR}/cmake/project.cmake")
include("${CMAKE_SOURCE_DIR}/cmake/Common.cmake")

cmake_minimum_required(VERSION "2.8.4")
project("${project_name}" C)
string(TOLOWER "${project_name}" project_name_lower)

set(CMAKE_INSTALL_PREFIX "/usr")
set(bindir "bin")
set(datarootdir "share")
set(libdir "lib")
set(includedir "include")
set(datadir "${datarootdir}/${project_name_lower}")
set(localedir "${datarootdir}/locale")
set(appdir "${datarootdir}/applications")
set(pixrootdir "${datarootdir}/pixmaps")
set(pixdir "${pixrootdir}/${project_name_lower}")
set(docdir "${datadir}/doc")
set(mandir "${datarootdir}/man")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/vala")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")


find_package(Vala "0.16" REQUIRED)

if(VALA_VERSION STRGREATER "0.19.0")
  list(REMOVE_ITEM required_pkgs "libvala-0.18" )
  list(REMOVE_ITEM required_pkgs "libvala-0.16" )
  set(valashort_ver "0.20")
  set(valac_cond)
elseif(VALA_VERSION STRGREATER "0.17.0")
  list(REMOVE_ITEM required_pkgs "libvala-0.20" )
  list(REMOVE_ITEM required_pkgs "libvala-0.16" )
  set(valashort_ver "0.18")
  set(valac_cond)
else()
  list(REMOVE_ITEM required_pkgs "libvala-0.20" )
  list(REMOVE_ITEM required_pkgs "libvala-0.18" )
  set(valashort_ver "0.16")
  set(valac_cond "-D;VALA_LESS_0_18")
endif()
set(vala_datadir "/usr/share/vala")
set(vapidir "${vala_datadir}-${valashort_ver}/vapi")



set(default_vala_flags
  "--thread"
  "--target-glib" "2.32"
  ${debug_opt}
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
    ${vapifiles}
  OPTIONS
    ${default_vala_flags}
)


# Set common C-macros.
add_definitions(-DPACKAGE_NAME="${project_name}")
add_definitions(-DPACKAGE_VERSION="${${project_name}_VERSION}")
if(project_root)
  add_definitions(-DGETTEXT_PACKAGE="${project_root}")
else()
  add_definitions(-DGETTEXT_PACKAGE="${project_name_lower}")
endif()
add_definitions(-DPACKAGE_DATA_DIR="${CMAKE_INSTALL_PREFIX}/${datadir}")
add_definitions(-DLOCALE_DIR="${CMAKE_INSTALL_PREFIX}/${localedir}")
add_definitions(-DPIXMAP_DIR="${CMAKE_INSTALL_PREFIX}/${pixdir}")
add_definitions(-DVALA_VERSION="${valashort_ver}")


add_executable("${project_name_lower}" ${VALA_C})
target_link_libraries("${project_name_lower}" ${PROJECT_LDFLAGS})
add_definitions(${PROJECT_C_FLAGS})
install(TARGETS ${project_name_lower} DESTINATION "${bindir}")


# Print some information about build.
message("")
message("---------------------------------------------")
message("")
message("${project_name} ${${project_name}_VERSION}")
message("")
if(CMAKE_BUILD_TYPE)
  message("Build type: ${CMAKE_BUILD_TYPE}")
  string(TOUPPER "${CMAKE_BUILD_TYPE}" release_upper)
  set(c_flags "${CMAKE_C_FLAGS_${release_upper}}")
else()
  message("Build type: Default")
  set(c_flags "${CMAKE_C_FLAGS}")
endif()
message("")
message("Installation prefix:    ${CMAKE_INSTALL_PREFIX}")
message("Gettext package:        ${project_name_lower}")
base_list_to_delimited_string(vala_flags
  DELIM " "
  BASE_LIST "${default_vala_flags}")
message("C compiler:             ${CMAKE_C_COMPILER}")
message("C compiler version      ${CMAKE_C_COMPILER_VERSION}")
if("${c_flags}" STREQUAL "")
  set(c_flags "(none)")
endif()
message("C flags:                ${c_flags}")
message("Vala compiler:          ${VALA_EXECUTABLE}")
message("Vala compiler version:  ${VALA_VERSION}")
if("${vala_flags}" STREQUAL "")
  set(vala_flags "(none)")
endif()
message("Vala flags:             ${vala_flags}")
message("")
# if(DOCS)
#   message("Build documentation:    enabled")
# else()
#   message("Build documentation:    enabled")
# endif()
# if(TRANSLATION_BUILD)
#   message("Build translations:     enabled")
# else()
#   message("Build translations:     disabled")
# endif()
# if(GETTEXT_PACKAGE_NAME)
#   if(GETTEXT_PACKAGE_VERSION)
#     message("Gettext package:        ${GETTEXT_PACKAGE_NAME} (${GETTEXT_PACKAGE_VERSION})")
#   else()
#     message("Gettext package:        ${GETTEXT_PACKAGE_NAME}")
#   endif()
# endif()
if(CMAKE_VERBOSE_MAKEFILE)
  message("Verbose build:          enabled")
else()
  message("Verbose build:          disabled")
endif()
message("")
message("---------------------------------------------")
message("")

# vim: set ai ts=2 sts=2 et sw=2
