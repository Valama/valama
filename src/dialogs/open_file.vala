/*
 * src/dialogs/open_file.vala
 * Copyright (C) 2013, Valama development team
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

public class UiTemplateOpener : TemplatePage {
    private FileChooserWidget chooser_open;

    private bool initialized = false;
    private bool valid = false;

    public UiTemplateOpener (string? nextpage = null, string? prevpage = null) {
        if (nextpage != null)
            default_next = nextpage;
        if (prevpage != null)
            default_prev = prevpage;

        description = _("Select Valama project file");

        var vbox = new Box (Orientation.HORIZONTAL, 0);
        selected.connect (() => {
            if (!initialized) {
                init();
                vbox.pack_start (chooser_open, true, true);
                vbox.show_all();
            }
            Idle.add (() => {
                prev (true);
                chooser_open.grab_focus();
                return false;
            });
        });
        deselected.connect ((status) => {
            if (status)
                try {
                    load_project (new ValamaProject (chooser_open.get_filename(), Args.syntaxfile));
                } catch (LoadingError e) {
                    //TODO: Show error message in UI.
                    error_msg (_("Could not load project: %s\n"), e.message);
                }
        });

        vbox.show_all();
        widget = vbox;
    }

    public override string get_id() {
        return "UiTemplateOpener";
    }

    protected override void init() {
        initialized = true;
        chooser_open = new FileChooserWidget (FileChooserAction.OPEN);
        chooser_open.expand = true;

        var filter_vlp = new FileFilter();
        filter_vlp.set_filter_name (_("Valama project files (*.vlp)"));
        filter_vlp.add_pattern ("*.vlp");
        chooser_open.add_filter (filter_vlp);
        chooser_open.set_filter (filter_vlp);  // set default filter

        var filter_all = new FileFilter();
        // TRANSLATORS: (*) is a file filter (globbing) and matches all files.
        filter_all.set_filter_name (_("All files (*)"));
        filter_all.add_pattern ("*");
        chooser_open.add_filter (filter_all);

        chooser_open.selection_changed.connect (() => {
            var selected_filename = chooser_open.get_filename();
            if (selected_filename == null ||  //TODO: Other filetypes?
                        File.new_for_path (selected_filename).query_file_type (
                                                FileQueryInfoFlags.NONE) != FileType.REGULAR)
                valid = false;
            else
                valid = selected_filename.has_suffix (".vlp");
            next (valid);
        });
        /* Double click. */
        chooser_open.file_activated.connect (() => {
            if (valid)
                move_next();
        });
    }
}

// vim: set ai ts=4 sts=4 et sw=4
