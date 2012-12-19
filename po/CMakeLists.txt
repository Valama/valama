# Translation stuff.
set(VERSION "${${project_name}_VERSION}")
include(Gettext)
IF(XGETTEXT_FOUND)
  set(all_srcfiles "")
  foreach(globexpr "${PROJECT_SOURCE_DIR}/src/*.vala")
    set(tmpsrcfiles "")
    file(GLOB tmpsrcfiles ${globexpr})
    set(tmpsrcfile "")
    foreach(tmpsrcfile ${tmpsrcfiles})
      file(RELATIVE_PATH srcfile ${CMAKE_CURRENT_BINARY_DIR} ${tmpsrcfile})
      list(APPEND all_srcfiles "${CMAKE_CURRENT_BINARY_DIR}/${srcfile}")
    endforeach()
  endforeach()
  set(potfile "${PROJECT_SOURCE_DIR}/po/valama.pot")
  GETTEXT_CREATE_POT("${potfile}"
    OPTION
      ${XGETTEXT_OPTIONS_DEFAULT}
      #"--msgid-bugs-address" "mail@mail.org"
    SRC
      ${all_srcfiles}
  )
  file(GLOB pofiles "${CMAKE_CURRENT_SOURCE_DIR}/*.po")
  GETTEXT_CREATE_TRANSLATIONS("${potfile}"
    ALL ${pofiles}
    COMMENT "Create translation."
  )
endif()
