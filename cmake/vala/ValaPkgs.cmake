#
# cmake/vala/vala-pkgs.cmake
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
##
# The vala_pkgs function is a wrapper to perform pkg-config check,
# automatically set compiler and linker flags and call the actual
# vala_precompile function.
#
# Supported sections:
#
# PACKAGES
#   A list of vala packages that are required to build the target.
#
# OPTIONAL
#   A list of vala packages that are optional to build the target. (optional)
#
# SRCFILES
#   A list of Vala source files. Globbing is supported.
#
# VAPIS
#   A list of custom .vapi files. Globbing is supported. (optional)
#
# OPTIONS
#   A list of options passed to the valac compiler. (optional)
#
#
# The following call is a simple example:
#
#   SET(packages "foo >= 1.4.2" "bla <= 9")
#   vala_pkgs(VALA_C
#     PACKAGES
#       gtk+-3.0
#       gee-1.0
#       ${packages}
#     OPTIONAL
#       libxml-2.0
#     SRCFILES
#       file.vala
#       file2.vala
#       src/file3.vala
#   )
#   add_executable(myexecutable ${VALA_C})
#
include(CMakeParseArguments)
function(vala_pkgs output)
  cmake_parse_arguments(ARGS "" "" "PACKAGES;OPTIONAL;SRCFILES;VAPIS;OPTIONS" ${ARGN})


  if(ARGS_PACKAGES OR ARGS_OPTIONAL)
    find_package(PkgConfig)
  endif()

  if(ARGS_SRCFILES)
    include(UseVala)

    # Package list without versions to pass to vala_precompile.
    set(pkglist "")

    set(required_pkgs "")
    if(ARGS_PACKAGES)
      foreach(pkg ${ARGS_PACKAGES})
        string(TOUPPER ${pkg} pkgdesctmp)
        string(REGEX REPLACE "([A-Z0-9-])[-+]*([0-9.]*)$" "\\1\\2" pkgdesc ${pkgdesctmp})
        pkg_check_modules(${pkgdesc} REQUIRED ${pkg})
        if (${${pkgdesc}_FOUND})
          list(APPEND required_pkgs ${pkgdesc})
          string(REGEX REPLACE "([^ ]+)" "\\1" pkgname ${pkg})
          list(APPEND pkglist ${pkgname})
        endif()
      endforeach()
    endif()

    set(optional_pkgs "")
    if(ARGS_OPTIONAL)
      foreach(pkg ${ARGS_OPTIONAL})
        string(TOUPPER ${pkg} pkgdesctmp)
        string(REGEX REPLACE "([A-Z0-9-])[-+]*([0-9.]*)$" "\\1\\2" pkgdesc ${pkgdesctmp})
        pkg_check_modules(${pkgdesc} ${pkg})
        if(${${pkgdesc}_FOUND})
          list(APPEND optional_pkgs ${pkgdesc})
          string(REGEX REPLACE "([^ ]+)" "\\1" pkgname ${pkg})
          list(APPEND pkglist ${pkgname})
        endif()
      endforeach()
    endif()

    set(definitions "")
    set(libraries "")
    foreach(pkg ${required_pkgs} ${optional_pkgs})
      list(APPEND definitions ${${pkg}_CFLAGS})
      list(APPEND libraries ${${pkg}_LIBRARIES})
    endforeach()
    foreach(pkg ${optional_pkgs})
      list(APPEND definitions ${${pkg}_CFLAGS})
      list(APPEND libraries ${${pkg}_LIBRARIES})
    endforeach()
    add_definitions(${definitions})
    link_libraries(${libraries})

    set(srcfiles "")
    foreach(globexpr ${ARGS_SRCFILES})
      file(GLOB tmpsrcfiles ${globexpr})
      foreach(tmpsrcfile ${tmpsrcfiles})
        file(RELATIVE_PATH srcfile ${CMAKE_CURRENT_SOURCE_DIR} ${tmpsrcfile})
        list(APPEND srcfiles ${srcfile})
      endforeach()
    endforeach()

    set(vapifiles "")
    if(ARGS_VAPIS)
      foreach(globexpr ${ARGS_VAPIS})
        file(GLOB tmpvapifiles ${globexpr})
        foreach(tmpvapifile ${tmpvapifiles})
          file(RELATIVE_PATH vapifile ${CMAKE_CURRENT_SOURCE_DIR} ${tmpvapifile})
          list(APPEND vapifiles ${vapifile})
        endforeach()
      endforeach()
    endif()

    vala_precompile(VALA_C
        ${srcfiles}
      PACKAGES
        ${pkglist}
      CUSTOM_VAPIS
        ${vapifiles}
      OPTIONS
        ${ARGS_OPTIONS}
    )

    set(${output} ${VALA_C} PARENT_SCOPE)
  endif()
endfunction()

# vim: set ai ts=2 sts=2 et sw=2
