/*
 * guanako/guanako_helpers.vala
 * Copyright (C) 2012, 2013, Valama development team
 *
 * Valama is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Valama is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

using GLib;
using Vala;

namespace Guanako {

     //Helper function for checking whether a given source location is inside a SourceReference
    public static bool before_source_ref (SourceFile source_file,
                                          int source_line,
                                          int source_col,
                                          SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
#if VALA_LESS_0_18
        if (reference.first_line > source_line)
#else
        if (reference.begin.line > source_line)
#endif
            return true;
#if VALA_LESS_0_18
        if (reference.first_line == source_line && reference.first_column > source_col)
#else
        if (reference.begin.line == source_line && reference.begin.column > source_col)
#endif
            return true;
        return false;
    }

    public static bool after_source_ref (SourceFile source_file,
                                         int source_line,
                                         int source_col,
                                         SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
#if VALA_LESS_0_18
        if (reference.last_line < source_line)
#else
        if (reference.end.line < source_line)
#endif
            return true;
#if VALA_LESS_0_18
        if (reference.last_line == source_line && reference.last_column < source_col)
#else
        if (reference.end.line == source_line && reference.end.column < source_col)
#endif
            return true;
        return false;
    }

    public static bool inside_source_ref (SourceFile source_file,
                                          int source_line,
                                          int source_col,
                                          SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
#if VALA_LESS_0_18
        if (reference.first_line > source_line || reference.first_line < source_line)
#else
        if (reference.begin.line > source_line || reference.end.line < source_line)
#endif
            return false;
#if VALA_LESS_0_18
        if (reference.first_line == source_line && reference.first_column > source_col)
#else
        if (reference.begin.line == source_line && reference.begin.column > source_col)
#endif
            return false;
#if VALA_LESS_0_18
        if (reference.last_line == source_line && reference.last_column < source_col)
#else
        if (reference.end.line == source_line && reference.end.column < source_col)
#endif
            return false;
        return true;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
