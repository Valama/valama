#
# guanako/CMakeLists.txt
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

include("${CMAKE_SOURCE_DIR}/cmake/guanako.cmake")
include("${CMAKE_SOURCE_DIR}/cmake/Common.cmake")

if(CMAKE_MAJOR_VERSION GREATER "2")
  cmake_policy(SET CMP0048 NEW)
  project("${project_name}" VERSION "${${project_name}_VERSION}" LANGUAGES "C")
else()
  project("${project_name}" "C")
endif()
string(TOLOWER "${project_name}" project_name_lower)

# export (sub)project version
if(project_root)
  set("${project_name}_VERSION" "${${project_name}_VERSION}" PARENT_SCOPE)
endif()

set(bindir "bin")
set(datarootdir "share")
set(libdir "lib")
set(includedir "include")
set(datadir "${datarootdir}/${project_name_lower}")
set(uidir "${datadir}/ui")
if(NOT project_root OR NOT datadir)
  set(datadir "${datarootdir}/${project_name_lower}")
endif()
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


set(pc_prefix ${CMAKE_INSTALL_PREFIX})
set(pc_exec_prefix "\${prefix}")
set(pc_libdir "\${exec_prefix}/${libdir}")
set(pc_includedir "\${prefix}/${includedir}")
set(pc_datarootdir "\${prefix}/${datarootdir}")
set(pc_vapidir "\${datarootdir}/vala-${VALA_SHORTVER}/vapi")
set(pc_version "${${project_name}_VERSION}")


# Custom library version checks.
set(definitions)
set(vapidirs)
find_package(PkgConfig)
# config
list(REMOVE_ITEM required_pkgs "config {nocheck,nolink}")
# libvala-X.Y
if(VALA_SHORTVER STREQUAL "0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(REMOVE_ITEM required_pkgs "libvala-0.28")
  list(REMOVE_ITEM required_pkgs "libvala-0.30")
  list(APPEND definitions "VALAC_0_20")
elseif(VALA_SHORTVER STREQUAL "0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(REMOVE_ITEM required_pkgs "libvala-0.28")
  list(REMOVE_ITEM required_pkgs "libvala-0.30")
  list(APPEND definitions "VALAC_0_20")
elseif(VALA_SHORTVER STREQUAL "0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(REMOVE_ITEM required_pkgs "libvala-0.28")
  list(REMOVE_ITEM required_pkgs "libvala-0.30")
  list(APPEND definitions "VALAC_0_20")
elseif(VALA_SHORTVER STREQUAL "0.26")
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.28")
  list(REMOVE_ITEM required_pkgs "libvala-0.30")
  list(APPEND definitions "VALAC_0_26")
elseif(VALA_SHORTVER STREQUAL "0.28")
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(REMOVE_ITEM required_pkgs "libvala-0.30")
  list(APPEND definitions "VALAC_0_26")
elseif(VALA_SHORTVER STREQUAL "0.30")
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(REMOVE_ITEM required_pkgs "libvala-0.28")
  list(APPEND definitions "VALAC_0_26")
else()
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(REMOVE_ITEM required_pkgs "libvala-0.28")
  list(REMOVE_ITEM required_pkgs "libvala-0.30")
  list(APPEND required_pkgs "libvala-${VALA_SHORTVER}")
  list(APPEND definitions "VALAC_0_20")
endif()
# glib-2.0
pkg_check_modules(GLIB2.0 REQUIRED "glib-2.0")


# Configure template files.
set(stripped_pkgs)
set(stripped_pkgs_pkgconfig)
foreach(pkgstr ${required_pkgs})
  set(matchit)
  string(REGEX MATCH "([^{ \t]*)[ \t]*{([^}]+,|)[ \t]*nocheck[ \t]*(|,[^}]+)}[ \t]*$" matchit ${pkgstr})
  string(REGEX REPLACE "^([^{ \t]*)[ \t]*{[^{}]*}[ \t]*$" "\\1" pkg ${pkgstr})
  if(NOT matchit)
    list(APPEND stripped_pkgs_pkgconfig "${pkg}")
  endif()

  string(REGEX REPLACE "^([^ \t]+).*" "\\1"  pkg_pkgconfig "${pkgstr}")
  list(APPEND stripped_pkgs "${pkg_pkgconfig}")
endforeach()
base_list_to_delimited_string(pc_requirements
  DELIM " "
  BASE_LIST ${stripped_pkgs_pkgconfig}
)
configure_file("${project_name_lower}.pc.in" "${project_name_lower}.pc" @ONLY)

base_list_to_delimited_string(deps_requirements
  DELIM "\n"
  BASE_LIST ${stripped_pkgs}
)
configure_file("${project_name_lower}.deps.in" "${project_name_lower}.deps")


set(default_vala_flags
  "--thread"
  "--target-glib" "${GLIB2.0_VERSION}"
  "--enable-experimental"
  #"--fatal-warnings"
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
  LIBRARY
    "${project_name_lower}"
  GIRFILE
    "${project_name}-${${project_name}_VERSION}"
  OPTIONS
    ${default_vala_flags}
    ${vapidirs}
)

add_library("${project_name_lower}" SHARED ${VALA_C})
set_target_properties("${project_name_lower}" PROPERTIES
    VERSION "${${project_name}_VERSION}"
    SOVERSION "${soversion}"
)
target_link_libraries("${project_name_lower}" ${PROJECT_LDFLAGS})
add_definitions(${PROJECT_C_FLAGS})

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

install(TARGETS "${project_name_lower}" DESTINATION "${libdir}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.pc" DESTINATION "lib/pkgconfig")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.h" DESTINATION "${includedir}")
set(vapi_files "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.deps" "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.vapi")
install(FILES ${vapi_files} DESTINATION "${VALA_VAPIDIR}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name}-${${project_name}_VERSION}.gir" DESTINATION "${datarootdir}/gir-1.0")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/syntax" DESTINATION "${datadir}")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/${project_name_lower}.lang" DESTINATION "${datarootdir}/gtksourceview-3.0/language-specs")

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

# vim: set ai ts=2 sts=2 et sw=2
