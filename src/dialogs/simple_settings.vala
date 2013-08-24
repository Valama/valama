/*
 * src/dialogs/simple_settings.vala
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

public class UiTemplateSettings : TemplatePage {
    private Grid grid_pinfo;

    private bool initialized = false;
    private bool has_content = false;

    public UiTemplateSettings (string? nextpage = null, string? prevpage = null) {
        if (nextpage != null)
            default_next = nextpage;
        if (prevpage != null)
            default_prev = prevpage;

        description = _("Project settings");

        var vbox = new Box (Orientation.HORIZONTAL, 0);
        selected.connect (() => {
            if (!initialized) {
                init();
                vbox.pack_start (grid_pinfo, true, true);
                vbox.show_all();
            }
            Idle.add (() => {
                if (has_content)
                    next (true);
                prev (true);
                grid_pinfo.grab_focus();
                return false;
            });
        });

        vbox.show_all();
        widget = vbox;
    }

    public override string get_id() {
        return "UiTemplateSettings";
    }

    protected override void init() {
        initialized = true;

        grid_pinfo = new Grid();
        grid_pinfo.column_spacing = 10;
        grid_pinfo.row_spacing = 15;
        grid_pinfo.row_homogeneous = false;
        grid_pinfo.column_homogeneous = true;

        var lbl_pname = new Label (_("Project name"));
        grid_pinfo.attach (lbl_pname, 0, 2, 1, 1);
        lbl_pname.halign = Align.END;

        var valid_chars = /^[a-z0-9.:_-]+$/i;  // keep "-" at the end!
        var ent_pname = new Entry.with_inputcheck (null, valid_chars);
        grid_pinfo.attach (ent_pname, 1, 2, 1, 1);
        ent_pname.set_placeholder_text (_("project name"));

        ent_pname.valid_input.connect (() => {
            next (true);
            has_content = true;
        });
        ent_pname.invalid_input.connect (() => {
            next (false);
            has_content = false;
        });

        var lbl_plocation = new Label (_("Location"));
        grid_pinfo.attach (lbl_plocation, 0, 5, 1, 1);
        lbl_plocation.halign = Align.END;

        //TODO: Use in place dialog (FileChooserWidget).
        var chooser_location = new FileChooserButton (_("New project location"),
                                                      Gtk.FileChooserAction.SELECT_FOLDER);
        chooser_location.set_current_folder (Environment.get_current_dir());
        grid_pinfo.attach (chooser_location, 1, 5, 1, 1);

        chooser_location.file_set.connect (() => {
            switch (chooser_location.get_file().query_file_type (FileQueryInfoFlags.NONE)) {
                case FileType.REGULAR:
                    chooser_location.set_current_folder (Path.get_dirname (chooser_location.get_filename()));
                    break;
                case FileType.DIRECTORY:
                    chooser_location.set_current_folder (chooser_location.get_filename());
                    break;
                default:
                    break;
            }
        });

        deselected.connect ((status) => {
            if (status && TemplatePage.template != null) {
                var target_folder = Path.build_path (Path.DIR_SEPARATOR_S,
                                                     chooser_location.get_current_folder(),
                                                     ent_pname.text);
                var new_project = create_project_from_template (
                                                TemplatePage.template,
                                                target_folder,
                                                ent_pname.text);
                load_project (new_project);
            }
        });
    }
}

// vim: set ai ts=4 sts=4 et sw=4
