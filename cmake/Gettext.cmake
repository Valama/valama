#
# cmake/Gettext.cmake
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
#
# Heavily based on Jim Nelson's Gettext.cmake in Geary project:
# https://github.com/ypcs/geary
#
##
# Add find_package handler for gettext programs msgmerge, msgfmt, msgcat and
# xgettext.
##
# Constant:
# XGETTEXT_OPTIONS_DEFAULT: Provide common xgettext options for vala.
##
# The gettext_create_pot macro creates .pot files with xgettext from multiple
# source files.
# Provide target 'pot_file' to generate .pot file.
#
# Supported sections:
#
# PACKAGE (optional)
#   Gettext package name. Get exported to parent scope.
#   Default: ${PROJECT_NAME}
#
# VERSION (optional)
#   Gettext package version. Get exported to parent scope.
#   Default: ${${GETTEXT_PACKAGE_NAME}_VERSION}
#   (${GETTEXT_PACKAGE_NAME} is package name from option above)
#
# OPTIONS (optional)
#   Pass list of xgettext options (you can use XGETTEXT_OPTIONS_DEFAULT
#   constant).
#   Default: ${XGETTEXT_OPTIONS_DEFAULT}
#
# SRCFILES (optional/mandatory)
#   List of source files to extract gettext strings from. Globbing is
#  supported.
#
# GLADEFILES (optional/mandatory)
#   List of glade source files to extract gettext strings from. Globbing is
#   supported.
#
# Either SRCFILES or GLADEFILES (or both) has to be filled with some files.
#
##
# The gettext_create_translations function generates .gmo files from .po files
# and install them as .mo files.
# Provide target 'translations' to build .gmo files.
#
# Supported sections:
#
# ALL (optional)
#   Make translations target a dependency of the 'all' target. (Build
#   translations with every build.)
#
# COMMENT (optional)
#   Cmake comment for translations target.
#
# PODIR (optional)
#   Directory with .po files.
#   Default: ${CMAKE_CURRENT_SOURCE_DIR}
#
# LOCALEDIR (optional)
#   Base directory where to install translations.
#   Default: share/cmake
#
# LANGUAGES (optional)
#   List of language 'short names'. This is in generel the part before the .po.
#   With English locale this is e.g. 'en_GB' or 'en_US' etc.
#
# POFILES (optional)
#   List of .po files.
#
##
#
# The following call is a simple example (within project po directory):
#
#   include(Gettext)
#   if(XGETTEXT_FOUND)
#     set(potfile "${CMAKE_CURRENT_SOURCE_DIR}/my_project.pot")
#     gettext_create_pot("${potfile}"
#       SRCFILES
#         "${PROJECT_SOURCE_DIR}/src/*.vala"
#     )
#     gettext_create_translations("${potfile}"
#       ALL
#       COMMENT
#         "Build translations."
#     )
#   endif()
#
##
find_program(GETTEXT_MSGMERGE_EXECUTABLE msgmerge)
find_program(GETTEXT_MSGFMT_EXECUTABLE msgfmt)
find_program(GETTEXT_MSGCAT_EXECUTABLE msgcat)
find_program(XGETTEXT_EXECUTABLE xgettext)
mark_as_advanced(GETTEXT_MSGMERGE_EXECUTABLE)
mark_as_advanced(GETTEXT_MSGFMT_EXECUTABLE)
mark_as_advanced(GETTEXT_MSGCAT_EXECUTABLE)
mark_as_advanced(XGETTEXT_EXECUTABLE)

if(XGETTEXT_EXECUTABLE)
  execute_process(COMMAND ${XGETTEXT_EXECUTABLE} "--version"
                  OUTPUT_VARIABLE gettext_version
                  ERROR_QUIET
                  OUTPUT_STRIP_TRAILING_WHITESPACE
  )
   if(gettext_version MATCHES "^xgettext \\(.*\\) [0-9]")
      string(REGEX REPLACE "^xgettext \\([^\\)]*\\) ([0-9\\.]+[^ \n]*).*" "\\1" GETTEXT_VERSION_STRING "${gettext_version}")
   endif()
   unset(gettext_version)
endif()


include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Gettext
  REQUIRED_VARS
    XGETTEXT_EXECUTABLE
    GETTEXT_MSGMERGE_EXECUTABLE
    GETTEXT_MSGFMT_EXECUTABLE
    GETTEXT_MSGCAT_EXECUTABLE
  VERSION_VAR
    GETTEXT_VERSION_STRING
)

if(XGETTEXT_EXECUTABLE AND GETTEXT_MSGMERGE_EXECUTABLE AND GETTEXT_MSGFMT_EXECUTABLE AND GETTEXT_MSGCAT_EXECUTABLE)
  set(XGETTEXT_FOUND TRUE)
  # Export variable to use it as status info.
  set(TRANSLATION_BUILD TRUE PARENT_SCOPE)
else()
  set(XGETTEXT_FOUND FALSE)
  set(TRANSLATION_BUILD FALSE PARENT_SCOPE)
endif()


set(XGETTEXT_OPTIONS_DEFAULT
  "--language" "C"
  "--keyword=_"
  "--keyword=N_"
  "--keyword=C_:1c,2"
  "--keyword=NC_:1c,2"
  "-s"
  "--escape"
  "--add-comments=\"/\""
  "--from-code=UTF-8"
)


if(XGETTEXT_FOUND)
  macro(gettext_create_pot potfile)
    cmake_parse_arguments(ARGS "" "PACKAGE;VERSION;WORKING_DIRECTORY" "OPTIONS;SRCFILES;GLADEFILES" ${ARGN})

    if(ARGS_PACKAGE)
      set(package_name "${ARGS_PACKAGE}")
    else()
      set(package_name "${PROJECT_NAME}")
    endif()

    if(ARGS_VERSION)
      set(package_version "${ARGS_VERSION}")
    else()
      set(package_version "${${package_name}_VERSION}")
    endif()
    # Export for status information.
    set(GETTEXT_PACKAGE_NAME "${package_name}" PARENT_SCOPE)
    set(GETTEXT_PACKAGE_VERSION "${package_version}" PARENT_SCOPE)

    if(ARGS_OPTIONS)
      set(xgettext_options
            "--package-name" "${package_name}"
            "--package-version" "${package_version}"
            ${ARGS_OPTIONS}
      )
    else()
      set(xgettext_options ${XGETTEXT_OPTIONS_DEFAULT}
            "--package-name" "${package_name}"
            "--package-version" "${package_version}"
      )
    endif()

    if(ARGS_SRCFILES OR ARGS_GLADEFILES)
      set(src_list)
      set(src_list_abs)
      foreach(globexpr ${ARGS_SRCFILES})
        set(tmpsrcfiles)
        file(GLOB tmpsrcfiles ${globexpr})
        if (tmpsrcfiles)
          foreach(tmpsrcfile ${tmpsrcfiles})
            get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${tmpsrcfile}" ABSOLUTE)
            file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
            list(APPEND src_list "${relFile}")
            list(APPEND src_list_abs "${absFile}")
          endforeach()
        else()
          get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${globexpr}" ABSOLUTE)
          file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
          list(APPEND src_list "${relFile}")
          list(APPEND src_list_abs "${absFile}")
        endif()
      endforeach()

      set(glade_list)
      set(glade_list_abs)
      foreach(globexpr ${ARGS_GLADEFILES})
        set(tmpgladefiles)
        file(GLOB tmpgladefiles ${globexpr})
        if (tmpgladefiles)
          foreach(tmpgladefile ${tmpgladefiles})
            get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${tmpgladefile}" ABSOLUTE)
            file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
            list(APPEND glade_list "${relFile}")
            list(APPEND glade_list_abs "${absFile}")
          endforeach()
        else()
          get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${globexpr}" ABSOLUTE)
          file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
          list(APPEND src_list "${relFile}")
          list(APPEND src_list_abs "${absFile}")
        endif()
      endforeach()

      add_custom_command(
        OUTPUT
          "pot_file"
        COMMAND
          ${XGETTEXT_EXECUTABLE} ${xgettext_options} "-o" "${CMAKE_CURRENT_BINARY_DIR}/${potfile}" ${src_list}
        DEPENDS
          ${src_list_abs}
          ${glade_list_abs}
        WORKING_DIRECTORY
          "${CMAKE_CURRENT_SOURCE_DIR}"
      )

      if(ARGS_SRCFILES AND ARGS_GLADEFILES)
        add_custom_target(pot_file
          COMMAND
            "${XGETTEXT_EXECUTABLE}" ${xgettext_options} "-o" "${CMAKE_CURRENT_BINARY_DIR}/_source.pot" ${src_list}
          COMMAND
            "${XGETTEXT_EXECUTABLE}" "--language=Glade" "--omit-header" "-o" "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot" ${glade_list}
          COMMAND
            "${GETTEXT_MSGCAT_EXECUTABLE}" "-o" "${potfile}" "--use-first" "${CMAKE_CURRENT_BINARY_DIR}/_source.pot" "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot"
          DEPENDS
            ${src_list_abs}
            ${glade_list_abs}
          WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}"
          COMMENT
            "Extract translateable messages to ${potfile}"
        )
      elseif(ARGS_SRCFILES)
        add_custom_target(pot_file
          COMMAND
            "${XGETTEXT_EXECUTABLE}" ${xgettext_options} "-o" "${CMAKE_CURRENT_BINARY_DIR}/_source.pot" ${src_list}
          COMMAND
            "${GETTEXT_MSGCAT_EXECUTABLE}" "-o" "${potfile}" "--use-first" "${CMAKE_CURRENT_BINARY_DIR}/_source.pot"
          DEPENDS
            ${src_list_abs}
            ${glade_list_abs}
          WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}"
          COMMENT
            "Extract translateable messages to ${potfile}"
        )
      else()
        add_custom_target(pot_file
          COMMAND
            "${XGETTEXT_EXECUTABLE}" "--language=Glade" "--omit-header" "-o" "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot" ${glade_list}
          COMMAND
            "${GETTEXT_MSGCAT_EXECUTABLE}" "-o" "${potfile}" "--use-first" "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot"
          DEPENDS
            ${src_list_abs}
            ${glade_list_abs}
          WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}"
          COMMENT
            "Extract translateable messages to ${potfile}"
        )
      endif()
    endif()
  endmacro()


  function(gettext_create_translations potfile)
    cmake_parse_arguments(ARGS "ALL" "COMMENT;PODIR;LOCALEDIR" "LANGUAGES;POFILES" ${ARGN})

    get_filename_component(_potBasename ${potfile} NAME_WE)
    get_filename_component(_absPotFile ${potfile} ABSOLUTE)

    if(ARGS_ALL)
      set(make_all "ALL")
    else()
      set(make_all)
    endif()

    if(ARGS_LOCALEDIR)
      set(_localedir "${ARGS_LOCALEDIR}")
    elseif(localedir)
      set(_localedir "${localedir}")
    else()
      set(_localedir "share/locale")
    endif()

    set(langs)
    list(APPEND langs ${ARGS_LANGUAGES})

    foreach(globexpr ${ARGS_POFILES})
      file(GLOB tmppofiles ${globexpr})
      foreach(tmppofile ${tmppofiles})
        string(REGEX REPLACE ".*/([a-zA-Z_]+)(\\.po)?$" "\\1" lang "${tmppofile}")
        list(APPEND langs "${lang}")
      endforeach()
    endforeach()

    if(NOT langs AND NOT ARGS_PODIR)
      set(ARGS_PODIR "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    if(ARGS_PODIR)
      file(GLOB pofiles "${ARGS_PODIR}/*.po")
      foreach(pofile ${pofiles})
        string(REGEX REPLACE ".*/([a-zA-Z_]+)\\.po$" "\\1" lang "${pofile}")
        list(APPEND langs "${lang}")
      endforeach()
    endif()

    list(REMOVE_DUPLICATES langs)


    set(_gmoFile)
    set(_gmoFiles)
    foreach (lang ${langs})
      get_filename_component(_absFile "${lang}.po" ABSOLUTE)
      get_filename_component(_abs_PATH "${_absFile}" PATH)
      set(_gmoFile "${CMAKE_CURRENT_BINARY_DIR}/${lang}.gmo")

      add_custom_command(
        OUTPUT
          "${_gmoFile}"
        COMMAND
          "${GETTEXT_MSGMERGE_EXECUTABLE}" "--quiet" "--update" "--backup=none" "-s" "${_absFile}" "${_absPotFile}"
        COMMAND
          "${GETTEXT_MSGFMT_EXECUTABLE}" "-o" "${_gmoFile}" "${_absFile}"
        DEPENDS
          "${_absPotFile}"
          "${_absFile}"
        WORKING_DIRECTORY
          "${CMAKE_CURRENT_BINARY_DIR}"
      )

      install(
        FILES
          "${_gmoFile}"
        DESTINATION
          "${localedir}/${lang}/LC_MESSAGES"
        RENAME
          "${_potBasename}.mo"
      )
      list(APPEND _gmoFiles "${_gmoFile}")
    endforeach()

    if(ARGS_COMMENT)
      add_custom_target(translations
        "${make_all}"
        DEPENDS
          ${_gmoFiles}
        COMMENT
          "${ARGS_COMMENT}" VERBATIM
      )
    else()
      add_custom_target(translations
        "${make_all}"
        DEPENDS
          ${_gmoFiles}
        COMMENT
          "Build translations." VERBATIM
      )
    endif()
  endfunction()
endif()

# vim: set ai ts=2 sts=2 et sw=2
