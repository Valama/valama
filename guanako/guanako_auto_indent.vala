/*
 * guanako/guanako_auto_indent.vala
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
    public static string auto_indent_buffer (Project project, SourceFile file) {
        string[] lines = file.content.split ("\n");
        for (int q = 0; q < lines.length; q++)
            lines[q] = lines[q].strip();

        foreach (var node in file.get_nodes()) {
            if (node is Symbol) {
                var cls = node as Symbol;
                iter_symbol (cls, (smb, depth) => {
                    if (smb is Subroutine) {
                        var sr = smb as Subroutine;
                        iter_subroutine (sr, (s, depth2) => {
                            for (int q = s.source_reference.begin.line - 1; q <= s.source_reference.end.line - 1; q++)
                                for (int i = 0; i < 1 + depth2; i++)
                                    lines[q] = "    " + lines[q];
                            return IterCallbackReturns.CONTINUE;
                        });
                    }
                    return IterCallbackReturns.CONTINUE;
                });
            }
        }

        string new_content = "";
        for (int q = 0; q < lines.length; q++) {
            new_content += lines[q];
            if (q < lines.length - 1)
                new_content += "\n";
        }
        return new_content;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
