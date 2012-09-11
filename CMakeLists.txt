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

cmake_minimum_required(VERSION 2.8)
project("Valama" C)

set(Valama_VERSION_MAJOR "0")
set(Valama_VERSION_MINOR "1")
#set(Valama_PATCH_VERSION_ "0")

set(VALAMA_VERSION "${Valama_VERSION_MAJOR}.${Valama_VERSION_MINOR}")

set(CMAKE_INSTALL_PREFIX "/usr")

#configure_file(
#  "${PROJECT_SOURCE_DIR}/config.vala.in"
#  "${PROJECT_SOURCE_DIR}/config.vala"
#)
#set_directory_properties(PROPERTY
#  ADDITIONAL_MAKE_CLEAN_FILES "${PROJECT_SOURCE_DIR}/config.vala")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/vala")
#list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(Vala "0.16" REQUIRED)


if(VALA_VERSION STRGREATER "0.17.0")
  set(valashort_ver "0.18")
  set(sourceref_begin "begin.")
  set(sourceref_end "end.")
else()
  set(valashort_ver "0.16")
  set(sourceref_begin "first_")
  set(sourceref_end "last_")
endif()

# Set Vala syntax depending on version.
# Replace @sourceref_begin@ and @sourceref_end@ .
configure_file(
  "${PROJECT_SOURCE_DIR}/src/ui_project_browser.vala.in"
  "${PROJECT_SOURCE_DIR}/src/ui_project_browser.vala"
)
configure_file(
  "${PROJECT_SOURCE_DIR}/src/guanako.vala.in"
  "${PROJECT_SOURCE_DIR}/src/guanako.vala"
)
configure_file(
  "${PROJECT_SOURCE_DIR}/src/main.vala.in"
  "${PROJECT_SOURCE_DIR}/src/main.vala"
)

set(required_pkgs "gtk+-3.0" "gtksourceview-3.0" "libvala-${valashort_ver}" "gee-1.0" "libxml-2.0")
#set(optional_pkgs "libxml-2.0 >= 0.1")
set(srcfiles "${PROJECT_SOURCE_DIR}/src/*.vala")
include(ValaPkgs)
vala_pkgs(VALA_C
  PACKAGES
    ${required_pkgs}
  OPTIONAL
    ${optional_pkgs}
  SRCFILES
    ${srcfiles}
)
if(NOT PkgConfig_FOUND)
  find_package(PkgConfig)
endif()
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
add_definitions(${GTHREAD_CFLAGS})
link_libraries(${GTHREAD_LIBRARIES})

add_executable(valama ${VALA_C})

# Create changelog on release.
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  execute_process(COMMAND git log
                  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
                  OUTPUT_FILE "Changelog")
endif()

if(CMAKE_BUILD_TYPE)
  message("Build type: ${CMAKE_BUILD_TYPE}")
else()
  message("Build type: default")
endif()

# Compress and install manpage.
#if(NOT MANPAGE_DISABLED)
#  add_custom_command(COMMAND gzip -cf9 "${PROJECT_SOURCE_DIR}/man/valama.1" >
#                      "${PROJECT_SOURCE_DIR}/man/valama.1.gz"
#                    OUTPUT "${PROJECT_SOURCE_DIR}/man/valama.1.gz"
#                    COMMENT "Generating manpage.")
#  add_custom_target(manpage ALL DEPENDS "${PROJECT_SOURCE_DIR}/man/valama.1.gz")
#  install(FILES "${PROJECT_SOURCE_DIR}/man/valama.1.gz" DESTINATION "share/man/man1")
#endif()

install(TARGETS valama DESTINATION "bin")

# Additional files.
install(FILES "data/syntax" DESTINATION "share/valama")
install(DIRECTORY "pixmaps/" DESTINATION "share/pixmaps/valama")
#install(DIRECTORY "data/folder" DESTINATION "share/valama")

# vim: set ai ts=2 sts=2 et sw=2
