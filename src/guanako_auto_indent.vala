/**
 * src/ui_project_browser.vala
 * Copyright (C) 2012, Linus Seelinger <S.Linus@gmx.de>
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
using Gtk;

namespace Guanako{
    public static void auto_indent_buffer(TextBuffer buffer){

        int lines = buffer.get_line_count();
        int depth = 0;

        for (int q = 0; q < lines - 1; q++){
            stdout.printf(q.to_string() + "\n");
            TextIter iter_start;
            buffer.get_iter_at_line(out iter_start, q);
            TextIter iter_end;
            buffer.get_iter_at_line(out iter_end, q);

            string text = buffer.get_slice(iter_start, iter_end, true);
            if (text.contains("{"))
                depth ++;
            else if (text.contains("{"))
                depth --;

            string new_text = text.strip();
            for (int i = 0; i < depth; i++)
                new_text = "    " + new_text;

            buffer.delete(ref iter_start, ref iter_end);
            buffer.insert(ref iter_start, new_text, new_text.length);
        }
    }

}