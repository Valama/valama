/*
 * src/dialogs/project_settings.vala
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

using Gtk;
using GLib;

/**
 * Show project settings window.
 *
 * @param project {@link ValamaProject} to edit settings.
 */
public void ui_project_dialog (ValamaProject? project) {
    var dlg = new Dialog.with_buttons (_("Project settings"),
                                       window_main,
                                       DialogFlags.MODAL,
                                       _("_Discard"),
                                       ResponseType.REJECT,
                                       _("_Cancel"),
                                       ResponseType.CANCEL,
                                       _("_Ok"),
                                       ResponseType.OK,
                                       null);
    dlg.set_size_request (600, 400);
    dlg.resizable = false;

    var headerbar = new HeaderBar();
    headerbar.title = _("Project settings");
    headerbar.show_all();
    dlg.set_titlebar(headerbar);

    var box_main = new Box (Orientation.VERTICAL, 0);

    var list = new Gtk.ListBox ();
    list.selection_mode = SelectionMode.NONE;
    list.row_selected.connect((row)=>{row.activate();}); //TODO: Possibly unnecessary in future GTK versions

    /* Set project name. */
    var row = new ListBoxRow();
    var box = new Box(Orientation.HORIZONTAL, 0);

    var lbl = new Label (_("Project name"));
    lbl.halign = Align.START;
    box.pack_start (lbl, true, true);

    var ent_proj_name_err = new Label ("");
    ent_proj_name_err.sensitive = false;

    Regex valid_chars = /^[a-z0-9.:_-]+$/i;  // keep "-" at the end!
    var ent_proj_name = new Entry.with_inputcheck (ent_proj_name_err, valid_chars);
    ent_proj_name.text = project.project_name;

    ent_proj_name.valid_input.connect (() => {
        dlg.set_response_sensitive (ResponseType.OK, true);
    });
    ent_proj_name.invalid_input.connect (() => {
        dlg.set_response_sensitive (ResponseType.OK, false);
    });

    box.pack_start (ent_proj_name, false, true);

    row.add (box);
    standardize_listbox_row (row);
    list.add (row);
    
    /*
     * Set project type : library/binary.
     */

    row = new ListBoxRow();
    var library_chekbtn = new CheckButton.with_label ("is library project");
    row.add (library_chekbtn);
    list.add (row);
    
    /*
     * Set build system type.
     */
    
    row = new ListBoxRow();
    var bslist = new ComboBoxText();
    BuildSystemTemplate.load_buildsystems();
    int i = 1;
    bool found = false;
    foreach (var bs in buildsystems.keys) {
        bslist.append_text (bs);
        if (!found) {
            if (bs == project.buildsystem)
                found = true;
        } else
            ++i;
    }
    if (found)
        bslist.active = i;
    row.add (bslist);
    list.add (row);
    
    /*
     * Set project version.
     * Format: X.Y.Z (major version, minor version, patch version)
     * Restrict major and minor version number to 999 which should be enough.
     */
    row = new ListBoxRow();
    box = new Box(Orientation.HORIZONTAL, 0);

    lbl = new Label (_("Version:"));
    lbl.halign = Align.START;
    box.pack_start (lbl, true, true);

    var ent_major = new SpinButton.with_range (0, 999, 1);
    ent_major.value = (double) project.version_major;
    box.pack_start (ent_major, false, false);

    var ent_minor = new SpinButton.with_range (0, 999, 1);
    ent_minor.value = (double) project.version_minor;
    box.pack_start (ent_minor, false, false);

    var ent_patch = new SpinButton.with_range (0, 9999, 1);
    ent_patch.value = (double) project.version_patch;
    box.pack_start (ent_patch, false, false);

    row.add (box);
    standardize_listbox_row (row);
    list.add (row);
    
    row = new ListBoxRow();
    var flags_lbl = new Label (_("Additional flags"));
    var flags_entry = new Entry();
    if (project.flags != null)
		flags_entry.text = project.flags;
    box = new Box (Orientation.VERTICAL, 0);
    box.pack_start (flags_lbl, false, false);
    box.pack_start (flags_entry, true, false);
    row.add (box);
    list.add (row);

    /* Save changes only when "OK" button is clicked. Reset on "Discard". */
    dlg.response.connect ((response_id) => {
        switch (response_id) {
            case ResponseType.OK:
                if (project.project_name != ent_proj_name.text) {
                    project.project_name = ent_proj_name.text;
                    project.save_to_recent();  // update recent list immediately
                }
                project.version_major = (int) ent_major.value;
                project.version_minor = (int) ent_minor.value;
                project.version_patch = (int) ent_patch.value;
                project.flags = flags_entry.text;
                project.library = library_chekbtn.active;
                if (bslist.active >= 0)
                    project.buildsystem = bslist.get_active_text();
                project.save_project_file();
                dlg.destroy();
                break;
            case ResponseType.CANCEL:
            case ResponseType.DELETE_EVENT:  // window manager close
                dlg.destroy();
                break;
            case  ResponseType.REJECT:
                /* Set label this first, perhaps insert_text will recognize
                 * unwanted characters (but this would be a bug if it is not
                 * already recognized before). */
                ent_proj_name_err.set_label ("");
                ent_proj_name.disable_timer();

                ent_proj_name.text = project.project_name;
                ent_major.value = (double) project.version_major;
                ent_minor.value = (double) project.version_minor;
                ent_patch.value = (double) project.version_patch;
                //ent_version_special.text = project.version_special;
                library_chekbtn.active = project.library;
                if (project.buildsystem != "") {
                    int j = 0;
                    bool found2 = false;
                    TreeIter iter;
                    if (bslist.model.get_iter_first (out iter))
                        do {
                            Value bs;
                            bslist.model.get_value (iter, 0, out bs);
                            if ((string) bs == project.buildsystem) {
                                found2 = true;
                                bslist.active = j;
                                break;
                            }
                            ++j;
                        } while (bslist.model.iter_next (ref iter));
                    if (!found2)
                        bslist.active = -1;
                }
                break;
            default:
                bug_msg (_("Unexpected enum value: %s: %d\n"), "project_dialog - dlg.response.connect", response_id);
                dlg.destroy();
                break;
        }
    });


    /* Raise window. */
    var frame = new Frame(null);
    frame.add (list);
    var align = new Alignment (0.0f, 0.5f, 1.0f, 0.0f);
    align.add (frame);
    box_main.pack_start (align, true, true);
    box_main.show_all();

    dlg.get_content_area().pack_start (box_main);
    dlg.run();
}

// vim: set ai ts=4 sts=4 et sw=4
