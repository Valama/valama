#
# tests/CMakeLists.txt
# Copyright (C) 2013, Valama development team
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

set(extra_srcfiles
  "../src/project/package_management.vala"
  "../src/project/project_file.vala"
  "../src/common/args.vala"
  "../src/common/common.vala"
)
set(required_pkgs
  "gee-0.8"
  "gio-2.0"
  "libxml-2.0"
  "guanako"
  "posix {nocheck}"
)
set(vapifiles
  "../vapi/config.vapi"
)
set(datadirs
  "projectfile"
)

if(GUANAKO)
  list(REMOVE_ITEM required_pkgs "guanako")
  list(APPEND vapifiles "${CMAKE_BINARY_DIR}/guanako/guanako.vapi")
  list(APPEND required_pkgs "libvala-${VALA_SHORTVER}")
endif()

# Custom library version checks.
set(valac_cond)
find_package(PkgConfig)
# Unix or Windows
if(WIN32)
  list(APPEND valac_cond "-D;WIN32")
elseif(UNIX)
  list(APPEND valac_cond "-D;UNIX")
else()
  list(APPEND valac_cond "-D;NOT_UNIX")
  list(APPEND valac_cond "-D;NOT_WIN32")
endif()
# glib-2.0
pkg_check_modules(GLIB2.0 REQUIRED "glib-2.0")

set(default_vala_flags
  "--thread"
  "--target-glib" "${GLIB2.0_VERSION}"
  "--enable-experimental"
  "--fatal-warnings"
  ${valac_cond}
)

include(ValaPkgs)
vala_pkgs(VALA_C
  PACKAGES
    ${required_pkgs}
  SRCFILES
    "*.vala"
    ${extra_srcfiles}
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
add_definitions(-DLOCALE_DIR="${install_prefix}${localedir}")
add_definitions(-DPIXMAP_DIR="${install_prefix}${pixdir}")
add_definitions(-DVALA_VERSION="${VALA_SHORTVER}")

add_executable("tests" ${VALA_C})
target_link_libraries("tests" ${PROJECT_LDFLAGS})
add_definitions(${PROJECT_C_FLAGS})
if(GUANAKO)
  include_directories("${PROJECT_BINARY_DIR}/guanako")
  target_link_libraries("tests" "guanako")
endif()
add_dependencies("tests" "guanako" "valama")

copy_dirs(
  TARGET
    "copy_datafiles"
  DIRS
    ${datadirs}
)

add_custom_command(
  OUTPUT
    "tests.stamp"
  COMMAND
    "tests"
  COMMAND
    "${CMAKE_COMMAND}" -E touch "tests.stamp"
  DEPENDS
    "tests"
    "copy_datafiles"
  COMMENT
    "Run tests"
  VERBATIM
)

add_custom_target("run_tests"
  ALL
  DEPENDS
    "tests.stamp"
)

# enable_testing()
# add_test(
#   NAME
#     "Run\\ all\\ tests"
#   COMMAND
#     "tests"
# )

# vim: set ai ts=2 sts=2 et sw=2
