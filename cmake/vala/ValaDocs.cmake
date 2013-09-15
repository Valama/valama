#
# cmake/vala/ValaDocs.cmake
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
# The valadoc_gen function generates Vala documentation from .vala and .vapi
# source files. The first parameter is the project name.
# Provide target 'docs' to build documentation.
#
# Supported sections:
#
# ALL (optional)
#   Include this target in all builds.
#
# INSTALLDIR (optional)
#   Directory where to install documentation to.
#   Default: ${datadir}
#   If ${datadir} not defined: share/${package_name_lower}
#                 (where ${package_name_lower} is ${package_name} with letters)
#   If ${package_name} is not defined raise error.
#
# DOCDIR (optional)
#   Directory where to build documentation to.
#   Default: ${CMAKE_CURRENT_BINARY_DIR}/docs
#
# PACKAGES (in general mandatory)
#   List of all Vala packages the project depends on.
#
# DEFINITIONS (optional)
#   A list of symbols for conditional compilation.
#
# SRCFILES
#   List of all project files. Globbing is supported.
#
# OPTIONS (optional)
#   List of additional valadoc options.

if(VALADOC_FOUND)
  function(valadoc_gen package_name)
    cmake_parse_arguments(ARGS "ALL" "INSTALLDIR;DOCDIR" "PACKAGES;DEFINITIONS;SRCFILES;OPTIONS" ${ARGN})

    if(ARGS_SRCFILES)
      if(ARGS_ALL)
        set(make_all "ALL")
      else()
        set(make_all)
      endif()

      string(TOLOWER "${package_name}" package_name_lower)
      if(ARGS_INSTALLDIR)
        set(installdir "${ARGS_DOCDIR}")
      elseif(datadir)
        set(installdir "${datadir}")
      elseif(package_name)
        set(installdir "share/${package_name_lower}")
      else()
        message(SEND_ERROR "No installation directory given.")
      endif()

      if(ARGS_DOCDIR)
        set(docdir "${ARGS_DOCDIR}")
      else()
        set(docdir "${CMAKE_CURRENT_BINARY_DIR}/docs")
      endif()

      set(srcfiles)
      set(srcfiles_abs)
      foreach(globexpr ${ARGS_SRCFILES})
        file(GLOB tmpsrcfiles ${globexpr})
        if(tmpsrcfiles)
          foreach(tmpsrcfile ${tmpsrcfiles})
            file(RELATIVE_PATH srcfile "${CMAKE_CURRENT_BINARY_DIR}" "${tmpsrcfile}")
            list(APPEND srcfiles "${srcfile}")
            get_filename_component(srcfile_abs "${tmpsrcfile}" ABSOLUTE)
            list(APPEND srcfiles_abs "${srcfile_abs}")
          endforeach()
        else()
          file(RELATIVE_PATH srcfile "${CMAKE_CURRENT_BINARY_DIR}" "${globexpr}")
          list(APPEND srcfiles "${srcfile}")
          get_filename_component(srcfile_abs "${globexpr}" ABSOLUTE)
          list(APPEND srcfiles_abs "${srcfile_abs}")
        endif()
      endforeach()

      set(pkg_opts)
      foreach(pkg ${ARGS_PACKAGES})
        list(APPEND pkg_opts "--pkg=${pkg}")
      endforeach()

      set(valadoc_options
          "-o" "${docdir}"
          "--package-name" "${package_name}"
      )
      foreach(def ${ARGS_DEFINITIONS})
        list(APPEND valadoc_options "--define=${def}")
      endforeach()
      if(ARGS_OPTIONS)
        list(APPEND valadoc_options ${ARGS_OPTIONS})
      endif()

      add_custom_command(
        OUTPUT
          "${docdir}/index.html"
        COMMAND
          "${CMAKE_COMMAND}" -E remove_directory "${docdir}"
        COMMAND
          "${VALADOC_EXECUTABLE}" ${srcfiles} ${pkg_opts} ${valadoc_options}
        DEPENDS
          ${srcfiles_abs}
        VERBATIM
      )

      add_custom_target("docs-${package_name_lower}"
        ${make_all}
        DEPENDS
          "${docdir}/index.html"
        COMMENT
          "Generating documentation with valadoc."
      )

      install(
        DIRECTORY
          "${docdir}"
        DESTINATION
          "${installdir}"
        OPTIONAL
      )
    endif()
  endfunction()
endif()
