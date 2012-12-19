#
# CMakeLists.txt
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

include("${CMAKE_SOURCE_DIR}/cmake/project.cmake")

cmake_minimum_required(VERSION "2.8")
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
set(vala_datadir "/usr/share/vala")
set(vapidir "${vala_datadir}-${valashort_ver}/vapi")


add_subdirectory("guanako")
add_subdirectory("icons")
#add_subdirectory("po")

#set(optional_pkgs "libxml-2.0 >= 0.1")
list(REMOVE_ITEM required_pkgs "guanako")
set(srcfiles "${PROJECT_SOURCE_DIR}/src/*.vala")
set(default_vala_flags
  "--thread"
  "--vapidir" "${CMAKE_BINARY_DIR}/guanako"  # for local guanako.vapi
  "--pkg" "guanako"  # force it, otherwise it is not included with fst cmake run
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
    "${PROJECT_SOURCE_DIR}/vapi/config.vapi"
  OPTIONS
    ${default_vala_flags}
)
if(NOT PkgConfig_FOUND)
  find_package(PkgConfig)
endif()
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
add_definitions(${GTHREAD_CFLAGS})
link_libraries(${GTHREAD_LIBRARIES})

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
target_link_libraries("${project_name_lower}" "guanako")

# Create the docs.
#TODO: Add configuration options.
find_package(Valadoc)
if(VALADOC_FOUND)
  set(globexpr "")
  set(all_srcfiles "")
  foreach(globexpr "${PROJECT_SOURCE_DIR}/src/*.vala" "${PROJECT_SOURCE_DIR}/guanako/*.vala")
    set(tmpsrcfiles "")
    file(GLOB tmpsrcfiles ${globexpr})
    set(tmpsrcfile "")
    foreach(tmpsrcfile ${tmpsrcfiles})
      file(RELATIVE_PATH srcfile ${CMAKE_CURRENT_BINARY_DIR} ${tmpsrcfile})
      list(APPEND all_srcfiles ${srcfile})
    endforeach()
  endforeach()
  set(vala_pkg_opts "")
  list(REMOVE_ITEM required_pkgs "guanako")
  foreach(pkg ${required_pkgs};${optional_pkgs})
    list(APPEND vala_pkg_opts "--pkg=${pkg}")
  endforeach()

  add_custom_target(clear_doc
    ${CMAKE_COMMAND} -E remove_directory "${PROJECT_BINARY_DIR}/docs"
    COMMENT "Clear old documentations." VERBATIM)

  add_custom_target(doc
    ${VALADOC_EXECUTABLE} "-o" "docs"
        "${PROJECT_SOURCE_DIR}/vapi/config.vapi" ${all_srcfiles} ${vala_pkg_opts} ${custom_vapi_arguments}
        "--vapidir=${vapidir}"
        "--target-glib=2.32"
        "--private"
        "--internal"
        "--verbose"
        "--package-name=${project_name}"
    DEPENDS clear_doc
    COMMENT "Generating documentation with valadoc." VERBATIM)

  install(DIRECTORY "${PROJECT_BINARY_DIR}/docs/"
          DESTINATION "${docdir}" OPTIONAL)
endif()

# Create changelog on release.
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  execute_process(COMMAND git log
                  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                  OUTPUT_FILE "Changelog")
  #set(debug_opt "")
else(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(debug_opt "-D;DEBUG")
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
install(DIRECTORY "data/templates" DESTINATION "${datadir}")


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
if(DEBUG)
  message("Debug output:           enabled")
else()
  message("Debug output:           disabled")
endif()
if(THREADED)
  message("Multithreading support: enabled")
else()
  message("Multithreading support: disabled")
endif()
if(VALADOC_FOUND)
  message("Docs building support:  enabled")
else()
  message("Docs building support:  disabled")
endif()
if(CMAKE_VERBOSE_MAKEFILE)
  message("Verbose build:          enabled")
else()
  message("Verbose build:          disabled")
endif()
message("")
message("---------------------------------------------")
message("")

# vim: set ai ts=2 sts=2 et sw=2
