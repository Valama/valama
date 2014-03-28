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


option(TRANSLATION "Build translation." ON)
option(ICONS "Generate icons." ON)
option(TESTS "Run tests after after build." ON)
option(GUANAKO "Build guanako library." ON)
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  option(DOCS "Build documentation." ON)
else()
  option(DOCS "Build documentation." OFF)
endif()
option(VALADOC_VERBOSE "Verbose (private/internal) document generation." OFF)
option(VALADOC_EXTRA "Generate documentation also for all depending packages." OFF)
if(VALADOC_VERBOSE OR VALADOC_EXTRA)
  set(DOCS ON)
endif()
option(CREATE_CHANGELOG "Create changelog from git log." OFF)
option(LOCAL "Add some functionality to execute directly from source directory." ON)
option(POSTINSTALL_HOOK "Execute hook scripts (gsettings update) after installation." ON)

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
set(definitions)
find_package(PkgConfig)
# Unix or Windows
if(WIN32)
  list(APPEND definitions "WIN32")
elseif(UNIX)
  list(APPEND definitions "UNIX")
else()
  list(APPEND definitions "NOT_UNIX")
  list(APPEND definitions "NOT_WIN32")
endif()
# libvala-X.Y
if(VALA_SHORTVER STREQUAL "0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(APPEND definitions "VALAC_0_20")
elseif(VALA_SHORTVER STREQUAL "0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(APPEND definitions "VALAC_0_20")
elseif(VALA_SHORTVER STREQUAL "0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(APPEND definitions "VALAC_0_20")
elseif(VALA_SHORTVER STREQUAL "0.26")
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(APPEND definitions "VALAC_0_20")
else()
  list(REMOVE_ITEM required_pkgs "libvala-0.20")
  list(REMOVE_ITEM required_pkgs "libvala-0.22")
  list(REMOVE_ITEM required_pkgs "libvala-0.24")
  list(REMOVE_ITEM required_pkgs "libvala-0.26")
  list(APPEND required_pkgs "libvala-${VALA_SHORTVER}")
  list(APPEND definitions "VALAC_0_20")
endif()
# gtk+-3.0
pkg_check_modules(GTK3.0 REQUIRED "gtk+-3.0 >= 3.10")
compare_version_strings("3.10" "${GTK3.0_VERSION}" gtkres)
if(gtkres LESS 1)
  list(APPEND definitions "GTK_3_10")
endif()
#gtksourceview-3.0
pkg_check_modules(GTKSV3.0 REQUIRED "gtksourceview-3.0 >= 3.10")
if((${GTKSV3.0_VERSION} GREATER 3.12) OR (${GTKSV3.0_VERSION} EQUAL 3.12))
	message(STATUS "SourceGutter is deprecated. Use get_window (WindowType type) on view directly.")
	list(APPEND definitions "GTK_SOURCE_VIEW_3_12")
endif()
# gdl-3.0
set(gdl_workarround OFF)
pkg_check_modules(GDL3.0 REQUIRED "gdl-3.0 >= 3.3.91")
compare_version_strings("3.9.91" "${GDL3.0_VERSION}" gdlres)
if(gdlres LESS 1)
  list(APPEND definitions "GDL_3_9_91")
  message(STATUS "Use enhanced gdl-3.0 vapi to support new "
                 "features with gdl-3.0 >= 3.9.91.")
  list(APPEND vapifiles "extravapi/gdl-3.0.vapi")
  list(REMOVE_ITEM required_pkgs "gdl-3.0 >= 3.3.91")
  set(gdl_workarround ON)
else()
  compare_version_strings("3.5.5" "${GDL3.0_VERSION}" gdlres)
  if(gdlres LESS 1)
    compare_version_strings("3.8.1" "${GDL3.0_VERSION}" gdlres)
    if(gdlres LESS 1)
      list(APPEND definitions "GDL_3_8")
    endif()
    compare_version_strings("0.20" "${VALA_SHORTVER}" valares)
    if(valares EQUAL 1)
      message(STATUS "Use enhanced gdl-3.0 vapi from valac 0.20 to support new "
                     "features with gdl-3.0 >= 3.5.5.")
      list(APPEND vapifiles "extravapi/gdl-3.0.vapi")
      list(REMOVE_ITEM required_pkgs "gdl-3.0 >= 3.3.91")
      set(gdl_workarround ON)
    endif()
  else()
    list(APPEND definitions "GDL_LESS_3_5_5")
    message(WARNING "With gdl-3.0 ${GDL3.0_VERSION} < 3.5.5 dock item "
                    "behaviour is poor: Hidden docks aren't saved in layout "
                    "and will open detached.\n"
                    "Please upgrade your gdl version or live with it.")
    compare_version_strings("0.20" "${VALA_SHORTVER}" valares)
    if(valares LESS 1)
      message(STATUS "Use gdl-3.0 vapi from valac 0.18 to support old "
                     "library gdl-3.0 < 3.5.5.")
      list(APPEND vapifiles "extravapi/gdl-3.0-old.vapi")
      list(REMOVE_ITEM required_pkgs "gdl-3.0 >= 3.3.91")
      set(gdl_workarround ON)
    endif()
  endif()
endif()
# glib-2.0
pkg_check_modules(GLIB2.0 REQUIRED "glib-2.0")

# gladeui-2.0
pkg_check_modules(GLADEUI2.0 REQUIRED "gladeui-2.0")
# vapidir option added, for custom gladeui-2.0 vapi
set(default_vala_flags
  "--thread"
  "--target-glib" "${GLIB2.0_VERSION}"
  "--enable-experimental"
  "--fatal-warnings"
  "--vapidir=${CMAKE_SOURCE_DIR}/vapi"
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
add_definitions(-DGETTEXT_PACKAGE="${project_name_lower}")
add_definitions(-DPACKAGE_DATA_DIR="${install_prefix}${datadir}")
add_definitions(-DPACKAGE_UI_DIR="${install_prefix}${uidir}")
add_definitions(-DLOCALE_DIR="${install_prefix}${localedir}")
add_definitions(-DPIXMAP_DIR="${install_prefix}${pixdir}")
add_definitions(-DVALA_VERSION="${VALA_SHORTVER}")

add_executable("${project_name_lower}" ${VALA_C})
target_link_libraries("${project_name_lower}" ${PROJECT_LDFLAGS} "-lm")
add_definitions(${PROJECT_C_FLAGS})
if(GUANAKO)
  include_directories("${PROJECT_BINARY_DIR}/guanako")
  target_link_libraries("${project_name_lower}" "guanako")
endif()

if(gdl_workarround)
  target_link_libraries("${project_name_lower}" ${GDL3.0_LDFLAGS})
  add_definitions(${GDL3.0_CFLAGS})
endif()


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
    foreach(pkgstr ${required_pkgs})
      string(REGEX REPLACE "^([^ \t]+).*" "\\1"  pkg "${pkgstr}")
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
  set(valadoc_pkgs)
  foreach(pkgstr ${required_pkgs} ${optional_pkgs})
    string(REGEX REPLACE "^([^ \t]+).*" "\\1"  pkg "${pkgstr}")
    list(APPEND valadoc_pkgs "${pkg}")
  endforeach()
  valadoc_gen("${project_name}"
    ${make_all}
    PACKAGES
      ${valadoc_pkgs}
    DEFINITIONS
      ${definitions}
    SRCFILES
      ${srcfiles}
      ${vapifiles}
    OPTIONS
      "--vapidir" "${VALA_VAPIDIR}"
      "--vapidir" "${VALA_DATADIR}/vapi"
      "--vapidir" "${CMAKE_SOURCE_DIR}/vapi"
      "--target-glib" "${GLIB2.0_VERSION}"
      ${extra_valadoc_opts}
      ${valadoc_debug}
  )
  if(GUANAKO)
    add_dependencies("docs-${project_name_lower}" "guanako")
  endif()
else()
  set(DOCS OFF)
endif()


# Run tests.
if(TESTS)
  add_subdirectory("tests")
endif()


if(CREATE_CHANGELOG)
  execute_process(COMMAND git log
                  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                  OUTPUT_FILE "Changelog")
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Release")
else(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CMAKE_VERBOSE_MAKEFILE ON)
endif()


# Generate and install manual page.
datestring(MONTH_DATE "%B %Y")
set(DATADIR "${install_prefix}${datadir}/")
set(manfile "data/${project_name_lower}.1")
configure_file("${manfile}.in" "${manfile}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${manfile}" DESTINATION "${mandir}/man1")


# Gsettings schemas
if(LOCAL)
  set(local_build "LOCAL")
else()
  set(local_build)
endif()
gsettings_install(${local_build} FILES "data/org.valama.gschema.xml")


install(TARGETS ${project_name_lower} DESTINATION "${bindir}")

# Additional files.
install(DIRECTORY "pixmaps/" DESTINATION "${pixdir}")
install(FILES "data/layout.xml" DESTINATION "${datadir}")
install(DIRECTORY "data/templates" DESTINATION "${datadir}")
install(DIRECTORY "data/buildsystems" DESTINATION "${datadir}")
install(FILES "data/valama.xml" DESTINATION "${mimedir}")

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
if(GUANAKO)
  set(guanako_text "  (Guanako ${Guanako_VERSION})")
else()
  set(guanako_text)
endif()
message("${project_name} ${${project_name}_VERSION}${guanako_text}")
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
foreach(def ${definitions})
  list(APPEND default_vala_flags "-D;${def}")
endforeach()
base_list_to_delimited_string(vala_flags
  DELIM " "
  BASE_LIST "${default_vala_flags}"
)
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
if(TESTS)
  message("Tests:                  enabled")
else()
  message("Tests:                  disabled")
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
