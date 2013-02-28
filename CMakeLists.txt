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


find_package(Vala "0.17" REQUIRED)


option(TRANSLATION "Build translation." ON)
option(ICONS "Generate icons." ON)
option(GUANAKO "Build guanako library." ON)
option(DOCS "Build documentation." OFF)
option(VALADOC_VERBOSE "Verbose (private/internal) document generation." OFF)
option(VALADOC_EXTRA "Generate documentation also for all depending packages." OFF)

if(GUANAKO)
  set(project_root "${project_name_lower}")
  set(project_root_version "${${project_name}_VERSION}")
  add_subdirectory("guanako")
  list(REMOVE_ITEM required_pkgs "guanako")
  list(APPEND vapifiles "${CMAKE_BINARY_DIR}/guanako/guanako.vapi")
endif()
if(ICONS)
  add_subdirectory("icons")
endif()
if(TRANSLATION)
  add_subdirectory("po")
endif()


# Custom library version checks.
set(valac_cond)
find_package(PkgConfig)
# libvala-X.Y
if(VALA_VERSION STRGREATER "0.19.0")
  list(REMOVE_ITEM required_pkgs "libvala-0.18")
  set(valashort_ver "0.20")
  set(valac_cond "-D;VALAC_0_20")
else()
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  set(valashort_ver "0.18")
endif()
set(vala_datadir "/usr/share/vala")
set(vapidir "${vala_datadir}-${valashort_ver}/vapi")
# gtk+-3.0
pkg_check_modules(GTK3.0 REQUIRED "gtk+-3.0")
if(NOT("3.6" STRGREATER GTK3.0_VERSION))
  list(APPEND valac_cond "-D;GTK_3_6")
endif()
# gdl-3.0
pkg_check_modules(GDL3.0 REQUIRED "gdl-3.0")
if(NOT("3.6.2" STRGREATER GDL3.0_VERSION))
  list(APPEND valac_cond "-D;GDL_3_6_2")
  if("0.20" STRGREATER "${valashort_ver}")
    message(WARNING "With gdl-3.0 ${GDL3.0_VERSION} >= 3.6.2 and valac "
                    "${valashort_ver} < 0.20 checks for dock item state "
                    "(is closed, attached etc.) are disabled.\n"
                    "Please upgrade your valac version or live with it.")
  endif()
elseif("3.5.5" STRGREATER GDL3.0_VERSION)
  message(WARNING "With gdl-3.0 ${GDL3.0_VERSION} < 3.5.5 dock item "
                  "behaviour is poor: Hidden docks aren't saved in layout "
                  "and will open detached.\n"
                  "Please upgrade your gdl version or live with it.")
endif()
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


set(default_vala_flags
  "--thread"
  "--target-glib" "2.32"
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
add_definitions(-DGETTEXT_PACKAGE="${project_name_lower}")
add_definitions(-DPACKAGE_DATA_DIR="${CMAKE_INSTALL_PREFIX}/${datadir}")
add_definitions(-DLOCALE_DIR="${CMAKE_INSTALL_PREFIX}/${localedir}")
add_definitions(-DPIXMAP_DIR="${CMAKE_INSTALL_PREFIX}/${pixdir}")
add_definitions(-DVALA_VERSION="${valashort_ver}")

# Set custom C-macros.
add_definitions(-DVALA_DATA_DIR="${vala_datadir}")

include_directories("${PROJECT_BINARY_DIR}/guanako")

add_executable("${project_name_lower}" ${VALA_C})
target_link_libraries("${project_name_lower}" ${PROJECT_LDFLAGS})
add_definitions(${PROJECT_C_FLAGS})
target_link_libraries("${project_name_lower}" "guanako")


# Create the docs.
find_package(Valadoc)
if(VALADOC_FOUND)
  include(ValaDocs)

  if(VALADOC_EXTRA)
    set(extra_valadoc_opts
      "--private"
      "--internal"
    )
  else()
    set(extra_valadoc_opts)
  endif()
  if(VALADOC_EXTRA)
    foreach(pkg ${required_pkgs})
      list(APPEND extra_valadoc_opts "--deps=${pkg}")
    endforeach()
  endif()
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(valadoc_debug "--verbose")
  else()
    set(valadoc_debug)
  endif()

  if(DOCS)
    set(make_all "ALL")
  else()
    set(make_all)
  endif()
  valadoc_gen("${project_name}"
    ${make_all}
    PACKAGES
      ${required_pkgs}
    SRCFILES
      ${srcfiles}
      ${vapifiles}
      "guanako/*.vala"
    OPTIONS
      "--vapidir" "${vapidir}"
      "--target-glib" "2.32"
      ${extra_valadoc_opts}
      ${valadoc_debug}
  )
else()
  set(DOCS OFF)
endif()


# Create changelog on release.
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  execute_process(COMMAND git log
                  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                  OUTPUT_FILE "Changelog")
  #set(DOCS ON)
else(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CMAKE_VERBOSE_MAKEFILE ON)
endif()


# Compress and install manpage.
#if(NOT MANPAGE_DISABLED)
#  add_custom_command(COMMAND gzip -cf9 "${PROJECT_SOURCE_DIR}/man/${project_name_lower}.1" >
#                      "${PROJECT_SOURCE_DIR}/man/${project_name_lower}.1.gz"
#                    OUTPUT "${PROJECT_SOURCE_DIR}/man/${project_name_lower}.1.gz"
#                    COMMENT "Generating manpage.")
#  add_custom_target(manpage ALL DEPENDS "${PROJECT_SOURCE_DIR}/man/${project_name_lower}.1.gz")
#  install(FILES "${PROJECT_SOURCE_DIR}/man/${project_name_lower}.1.gz" DESTINATION "${mandir}/man1")
#endif()


install(TARGETS ${project_name_lower} DESTINATION "${bindir}")

# Additional files.
install(DIRECTORY "pixmaps/" DESTINATION "${pixdir}")
install(FILES "data/${project_name_lower}.desktop" DESTINATION "${appdir}")
install(FILES "data/layout.xml" DESTINATION "${datadir}")
install(DIRECTORY "data/templates" DESTINATION "${datadir}")
install(DIRECTORY "data/buildsystems" DESTINATION "${datadir}")


# Print some information about build.
message("")
message("---------------------------------------------")
message("")
message("${project_name} ${${project_name}_VERSION}  (Guanako ${Guanako_VERSION})")
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
if(gee_ver)
  message("Gee version:            ${gee_ver}")
endif()
message("")
if(DOCS)
  if(VALADOC_VERBOSE AND VALADOC_EXTRA)
    message("Build documentation:    extra/verbose")
  elseif(VALADOC_VERBOSE)
    message("Build documentation:    verbose")
  elseif(VALADOC_EXTRA)
    message("Build documentation:    extra")
  else()
    message("Build documentation:    normal")
  endif()
else()
  message("Build documentation:    no")
endif()
if(TRANSLATION_BUILD)
  message("Build translations:     yes")
else()
  message("Build translations:     no")
endif()
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
