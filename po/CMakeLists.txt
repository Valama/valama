#
# po/CMakeLists.txt
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

include(Gettext)
if(XGETTEXT_FOUND)
  set(potfile "${PROJECT_SOURCE_DIR}/po/valama.pot")
  gettext_create_pot("${potfile}"
    SRCFILES
      "${PROJECT_SOURCE_DIR}/src/*.vala"
      "${PROJECT_SOURCE_DIR}/guanako/*.vala"
  )

  gettext_create_translations("${potfile}"
    ALL
    COMMENT
      "Build translations."
  )
endif()
