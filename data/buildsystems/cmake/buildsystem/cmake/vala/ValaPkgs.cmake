#
# cmake/vala/ValaPkgs.cmake
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
##
# The vala_pkgs function is a wrapper to perform pkg-config check,
# automatically set compiler and linker flags and call the actual
# vala_precompile function.
#
# Supported sections:
#
# PACKAGES
#   A list of vala packages that are required to build the target. Versioned
#   dependencies are supported. There is also a possibility to suppress
#   checking with pkg-config or to suppress --cflags and --libs of pkg-config.
#   To use those options append {option,option,...}.
#
# DEFINITIONS
#   A list of symbols for conditional compilation. (optional)
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
# LIBRARY
#   Name of library to generate.
#
# GIRFILE
#   Generate GObject-Introspection repository file.
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
#       "gtk+-3.0 >= 3.8"
#       gee-1.0
#       ${packages}
#       "sdl-image {nocheck,nolink}"
#       "sdl"
#     OPTIONAL
#       libxml-2.0
#     SRCFILES
#       file.vala
#       file2.vala
#       src/file3.vala
#   )
#   add_executable(myexecutable ${VALA_C})
#   target_link_libraries(myexecutable ${PROJECT_LDFLAGS})
#   add_definitions(${PROJECT_C_FLAGS})
#
include(CMakeParseArguments)
function(vala_pkgs output)
  cmake_parse_arguments(ARGS "" "LIBRARY;GIRFILE" "PACKAGES;DEFINITIONS;OPTIONAL;SRCFILES;VAPIS;OPTIONS" ${ARGN})


  if(ARGS_PACKAGES OR ARGS_OPTIONAL)
    find_package(PkgConfig)
  endif()

  if(ARGS_SRCFILES)
    include(UseVala)

    # Package list without versions to pass to vala_precompile.
    set(pkglist)

    set(definitions)
    set(libraries)

    if(ARGS_PACKAGES)
      foreach(pkg ${ARGS_PACKAGES})
        set(matchit)
        string(REGEX MATCH "([^{ \t]*)[ \t]*{([^}]+,|)[ \t]*nocheck[ \t]*(|,[^}]+)}[ \t]*$" matchit "${pkg}")
        string(REGEX REPLACE "^([^{ \t]*)[ \t]*{[^{}]*}[ \t]*$" "\\1" pkgstripped "${pkg}")

        if(NOT matchit)
          string(TOUPPER "${pkgstripped}" pkgdesctmp)
          string(REGEX REPLACE "([A-Z0-9-])[-+]*([0-9.]*)$" "\\1\\2" pkgdesc "${pkgdesctmp}")
          pkg_check_modules(${pkgdesc} REQUIRED ${pkgstripped})
          if (${${pkgdesc}_FOUND})
            set(matchit)
            string(REGEX MATCH "([^{ \t]*)[ \t]*{([^}]+,|)[ \t]*nolink[ \t]*(|,[^}]+)}[ \t]*$" matchit "${pkg}")
            if(NOT matchit)
              string(REGEX REPLACE "^([^{ \t]*)[ \t]*{[^{}]*}[ \t]*$" "\\1" pkgstripped "${pkg}")
              list(APPEND definitions "${${pkgdesc}_CFLAGS}")
              list(APPEND libraries "${${pkgdesc}_LDFLAGS}")
            endif()
          endif()
        endif()

        string(STRIP ${pkgstripped} tmppkgname)
        string(REGEX REPLACE "[ ].*$" "" pkgname "${tmppkgname}")
        list(APPEND pkglist "${pkgname}")
      endforeach()
    endif()

    set(optional_pkgs)
    if(ARGS_OPTIONAL)
      foreach(pkg ${ARGS_OPTIONAL})
        set(matchit)
        string(REGEX MATCH "([^{ \t]*)[ \t]*{([^}]+,|)[ \t]*nocheck[ \t]*(|,[^}]+)}[ \t]*$" matchit "${pkg}")
        string(REGEX REPLACE "^([^{ \t]*)[ \t]*{[^{}]*}[ \t]*$" "\\1" pkgstripped "${pkg}")

        if(NOT matchit)
          string(TOUPPER "${pkgstripped}" pkgdesctmp)
          string(REGEX REPLACE "([A-Z0-9-])[-+]*([0-9.]*)$" "\\1\\2" pkgdesc "${pkgdesctmp}")
          pkg_check_modules("${pkgdesc}" "${pkgstripped}")
          if(${${pkgdesc}_FOUND})
            set(matchit)
            string(REGEX MATCH "([^{ \t]*)[ \t]*{([^}]+,|)[ \t]*nolink[ \t]*(|,[^}]+)}[ \t]*$" matchit "${pkg}")
            if(NOT matchit)
              string(REGEX REPLACE "^([^{ \t]*)[ \t]*{[^{}]*}[ \t]*$" "\\1" pkgstripped "${pkg}")
              list(APPEND definitions "${${pkgdesc}_CFLAGS}")
              list(APPEND libraries "${${pkgdesc}_LDFLAGS}")
            endif()
          endif()
        endif()

        string(STRIP "${pkgstripped}" tmppkgname)
        string(REGEX REPLACE "([^ ]+)" "\\1" pkgname "${tmppkgname}")
        list(APPEND pkglist "${pkgname}")
      endforeach()
    endif()

    pkg_check_modules(GTHREAD REQUIRED "gthread-2.0")
    if(GTHREAD_FOUND)
      list(APPEND definitions "${GTHREAD_CFLAGS}")
      list(APPEND libraries "${GTHREAD_LDFLAGS}")
    endif()

    set(srcfiles)
    foreach(globexpr ${ARGS_SRCFILES})
      set(tmpsrcfiles)
      file(GLOB tmpsrcfiles ${globexpr})
      if(tmpsrcfiles)
        foreach(tmpsrcfile ${tmpsrcfiles})
          set(srcfile)
          file(RELATIVE_PATH srcfile "${CMAKE_CURRENT_SOURCE_DIR}" "${tmpsrcfile}")
            list(APPEND srcfiles "${srcfile}")
        endforeach()
      else()
        list(APPEND srcfiles "${globexpr}")
      endif()
    endforeach()

    set(vapifiles)
    if(ARGS_VAPIS)
      foreach(globexpr ${ARGS_VAPIS})
        set(tmpvapifiles)
        file(GLOB tmpvapifiles ${globexpr})
        if(tmpvapifiles)
          foreach(tmpvapifile ${tmpvapifiles})
            set(vapifile)
            file(RELATIVE_PATH vapifile "${CMAKE_CURRENT_SOURCE_DIR}" "${tmpvapifile}")
              list(APPEND vapifiles "${vapifile}")
          endforeach()
        else()
          list(APPEND vapifiles "${globexpr}")
        endif()
      endforeach()
    endif()

    vala_precompile(VALA_C
        ${srcfiles}
      PACKAGES
        ${pkglist}
      DEFINITIONS
        "${ARGS_DEFINITIONS}"
      CUSTOM_VAPIS
        ${vapifiles}
      GENERATE_VAPI
        "${ARGS_LIBRARY}"
      GENERATE_HEADER
        "${ARGS_LIBRARY}"
      GENERATE_GIR
        "${ARGS_GIRFILE}"
      OPTIONS
        ${ARGS_OPTIONS}
      PUBLIC
    )

    set(${output} ${VALA_C} PARENT_SCOPE)
    set(PROJECT_C_FLAGS ${definitions} PARENT_SCOPE)
    set(PROJECT_LDFLAGS ${libraries} PARENT_SCOPE)
  endif()
endfunction()

# vim: set ai ts=2 sts=2 et sw=2
