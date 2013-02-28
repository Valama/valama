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

include("${CMAKE_SOURCE_DIR}/cmake/guanako.cmake")
include("${CMAKE_SOURCE_DIR}/cmake/Common.cmake")

cmake_minimum_required(VERSION "2.8.4")
project("${project_name}" C)
string(TOLOWER "${project_name}" project_name_lower)

# export (sub)project version
if(project_root)
  set("${project_name}_VERSION" "${${project_name}_VERSION}" PARENT_SCOPE)
endif()

set(CMAKE_INSTALL_PREFIX "/usr")
set(bindir "bin")
set(datarootdir "share")
set(libdir "lib")
set(includedir "include")
if(NOT project_root OR NOT datadir)
  set(datadir "${datarootdir}/${project_name_lower}")
endif()
set(localedir "${datarootdir}/locale")
set(appdir "${datarootdir}/applications")
set(pixdir "${datarootdir}/pixmaps/${project_name_lower}")
set(docdir "${datadir}/doc")
set(mandir "${datarootdir}/man")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/vala")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")


find_package(Vala "0.17" REQUIRED)


set(pc_prefix ${CMAKE_INSTALL_PREFIX})
set(pc_exec_prefix "\${prefix}")
set(pc_libdir "\${exec_prefix}/${libdir}")
set(pc_includedir "\${prefix}/${includedir}")
set(pc_datarootdir "\${prefix}/${datarootdir}")
set(pc_vapidir "\${datarootdir}/${vapishort_dir}")
set(pc_version "${${project_name}_VERSION}")


# Custom library version checks.
set(valac_cond)
find_package(PkgConfig)
# libvala-X.Y
if(VALA_VERSION STRGREATER "0.19.0")
  list(REMOVE_ITEM required_pkgs "libvala-0.18" )
  set(valashort_ver "0.20")
else()
  list(REMOVE_ITEM required_pkgs "libvala-0.20" )
  set(valashort_ver "0.18")
endif()
set(vapishort_dir "vala-${valashort_ver}/vapi")
set(vapidir "/usr/share/${vapishort_dir}")
# gee-1.0 and gee-0.8
set(gee_ver)
set(all_pkgs)
list(APPEND all_pkgs ${required_pkgs} ${optional_pkgs})
set(gee0.8_contains)
list(FIND all_pkgs "gee-0.8" gee0.8_contains)
if(gee0.8_contains STRGREATER "-1")
  set(gee1.0_contains)
  list(FIND all_pkgs "gee-1.0" gee1.0_contains)
  if(gee1.0_contains STRGREATER "-1")
    pkg_check_modules(GEE0.8 "gee-0.8")
    pkg_check_modules(GEE1.0 "gee-1.0")
    if(GEE0.8_FOUND AND GEE1.0_FOUND)
      # Prefer first named package.
      if (gee0_8_contains STRGREATER gee1_0_contains)
        set(gee_ver "1.0")
        list(REMOVE_ITEM required_pkgs "gee-0.8")
        if(optional_pkgs)
          list(REMOVE_ITEM optional_pkgs "gee-0.8")
        endif()
      else()
        set(gee_ver "0.8")
        list(REMOVE_ITEM required_pkgs "gee-1.0")
        if(optional_pkgs)
          list(REMOVE_ITEM optional_pkgs "gee-1.0")
        endif()
      endif()
    elseif(GEE0.8_FOUND)
      set(gee_ver "0.8")
      list(REMOVE_ITEM required_pkgs "gee-1.0")
      if(optional_pkgs)
        list(REMOVE_ITEM optional_pkgs "gee-1.0")
      endif()
    elseif(GEE1.0_FOUND)
      set(gee_ver "1.0")
      list(REMOVE_ITEM required_pkgs "gee-0.8")
      if(optional_pkgs)
        list(REMOVE_ITEM optional_pkgs "gee-0.8")
      endif()
    endif()
  endif()
endif()


# Configure template files.
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


set(default_vala_flags
  "--thread"
  "-H" "${project_name_lower}.h"
  "--gir" "${project_name}-${${project_name}_VERSION}.gir"
  "--library" "${project_name_lower}"
  "--target-glib" "2.32"  # enable this to use new(tm) thread syntax
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
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/syntax" DESTINATION "${datadir}")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/${project_name_lower}.lang" DESTINATION "${datarootdir}/gtksourceview-3.0/language-specs")

# vim: set ai ts=2 sts=2 et sw=2
