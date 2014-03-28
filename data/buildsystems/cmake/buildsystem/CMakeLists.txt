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

cmake_minimum_required(VERSION "2.8.4")

include("${CMAKE_SOURCE_DIR}/cmake/project.cmake")
include("${CMAKE_SOURCE_DIR}/cmake/Common.cmake")

project("${project_name}" C)
string(TOLOWER "${project_name}" project_name_lower)

set(bindir "bin")
set(datarootdir "share")
set(libdir "lib")
set(includedir "include")
set(datadir "${datarootdir}/${project_name_lower}")
set(uidir "${datadir}/ui")
set(localedir "${datarootdir}/locale")
set(appdir "${datarootdir}/applications")
set(gsettingsdir "${datarootdir}/glib-2.0/schemas")
set(pixrootdir "${datarootdir}/pixmaps")
set(pixdir "${pixrootdir}/${project_name_lower}")
set(docdir "${datadir}/doc")
set(mandir "${datarootdir}/man")
set(mimedir "${datarootdir}/mime/packages")
if(CMAKE_INSTALL_PREFIX)
  set(install_prefix "${CMAKE_INSTALL_PREFIX}/")
else()
  set(install_prefix)
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/vala")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")


find_package(Vala "0.20" REQUIRED)

# Custom library version checks.
set(definitions)
find_package(PkgConfig)
# glib-2.0
pkg_check_modules(GLIB2.0 REQUIRED "glib-2.0")


set(default_vala_flags
  "--thread"
  "--target-glib" "${GLIB2.0_VERSION}"
)

include(ValaPkgs)
vala_pkgs(VALA_C
  PACKAGES
    ${required_pkgs}
  DEFINITIONS
    ${definitions}
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
add_definitions(-DPACKAGE_DATA_DIR="${install_prefix}${datadir}")
add_definitions(-DPACKAGE_UI_DIR="${install_prefix}${uidir}")
add_definitions(-DLOCALE_DIR="${install_prefix}${localedir}")
add_definitions(-DPIXMAP_DIR="${install_prefix}${pixdir}")
add_definitions(-DVALA_VERSION="${VALA_SHORTVER}")

add_executable("${project_name_lower}" ${VALA_C})
target_link_libraries("${project_name_lower}" ${PROJECT_LDFLAGS})
add_definitions(${PROJECT_C_FLAGS})
install(TARGETS ${project_name_lower} DESTINATION "${bindir}")

# Install user interface files if used and copy them to build directory.
set(uifiles_build)
foreach(uifile ${uifiles})
  add_custom_command(
    OUTPUT
      "${CMAKE_CURRENT_BINARY_DIR}/${uifile}"
    COMMAND
      "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/${uifile}" "${CMAKE_CURRENT_BINARY_DIR}/${uifile}"
    DEPENDS
      "${CMAKE_CURRENT_SOURCE_DIR}/${uifile}"
    COMMENT ""
  )
  list(APPEND uifiles_build "${CMAKE_CURRENT_BINARY_DIR}/${uifile}")
  install(FILES ${uifile} DESTINATION "${uidir}")
endforeach()
add_custom_target("ui_copy_${project_name_lower}" DEPENDS ${uifiles_build})
add_dependencies("${project_name_lower}" "ui_copy_${project_name_lower}")

# Uninstall target
add_custom_target(uninstall
  COMMAND
    "${CMAKE_COMMAND}" -D "CUSTOM_SOURCE_DIR:FILEPATH=${CMAKE_SOURCE_DIR}"
                       -D "POSTREMOVE_HOOK:BOOL=${POSTINSTALL_HOOK}"
                       -D "GSETTINGSDIR:FILEPATH=${install_prefix}${gsettingsdir}"
                       -P "${CMAKE_SOURCE_DIR}/cmake/SimpleUninstall.cmake"
)


# Print some information about build.
datestring(current_date "%F %T")
message("")
message("---------------------------------------------")
message("                          ${current_date}")
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
message("GLib version:           ${GLIB2.0_VERSION}")
message("")
if(GETTEXT_PACKAGE_NAME)
  if(GETTEXT_PACKAGE_VERSION)
    message("Gettext package:        ${GETTEXT_PACKAGE_NAME} (${GETTEXT_PACKAGE_VERSION})")
  else()
    message("Gettext package:        ${GETTEXT_PACKAGE_NAME}")
  endif()
endif()
if(CMAKE_VERBOSE_MAKEFILE)
  message("Verbose build:          yes")
else()
  message("Verbose build:          no")
endif()
message("")
message("---------------------------------------------")
message("")

# vim: set ai ts=2 sts=2 et sw=2
