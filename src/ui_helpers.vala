/**
* src/ui_create_file_dialog.vala
* Copyright (C) 2012, Dominique Lasserre <lasserre.d@gmail.com>
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

using Gtk;
using GLib;

/*
 * Check proper user input. Project names have to consist of "normal"
 * characters only (see regex below). Otherwise cmake would break.
 *
 * TODO: Perhaps we should internally handle special characters with
 *       underscore.
 *
 * TODO: Modify input_text signal directly.
 */
public class Entry : Gtk.Entry {
    uint timer_id = 0;
    Label err_label;
    Regex valid_chars;
    uint delay_sec;

    public Entry.with_inputcheck (Label err_label,
                                  Regex valid_chars,
                                  uint delay_sec = 5) {
        this.err_label = err_label;
        this.valid_chars = valid_chars;
        this.delay_sec = delay_sec;
        insert_text.connect((new_text) => {
            ui_check_input(new_text);
        });
    }

    ~Entry() {
        this.disable_timer();
    }

    public void ui_check_input (string input_text) {
        MatchInfo match_info = null;  // init to null to make valac happy
        if (!this.valid_chars.match (input_text, 0, out match_info)) {
            this.err_label.set_label (@"Invalid character: '$(match_info.get_string())' Please choose one from: " +
                                this.valid_chars.get_pattern());
            this.disable_timer();  // reset timer to let it start again
            this.timer_id = Timeout.add_seconds (this.delay_sec, (() => {
                this.err_label.set_label ("");
                return true;
            }));
            Signal.stop_emission_by_name(this, "insert_text");
        }
    }

    public void disable_timer() {
        if (this.timer_id != 0)
            Source.remove(this.timer_id);
    }
}
