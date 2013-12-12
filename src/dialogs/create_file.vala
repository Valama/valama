/*
 * src/dialogs/create_file.vala
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
using Vala;

/**
 * Create new file (you need to add it to project manually). If file already
 * exists, open it.
 *
 * @param path Root path of new file.
 * @param extension File extension.
 * @param directory Create directory.
 * @return Filename or `null`.
 */
public string? ui_create_file_dialog (string? path = null, string? extension = null,
                                      bool directory = false) {
    var dlg = new Dialog.with_buttons ((!directory) ? _("Choose filename")
                                                    : _("Choose directory name"),
                                       window_main,
                                       DialogFlags.MODAL,
                                       _("_Cancel"),
                                       ResponseType.CANCEL,
                                       (!directory) ? _("_Open") : _("_Add"),
                                       ResponseType.ACCEPT,
                                       null);

    dlg.set_size_request (420, 100);
    dlg.resizable = false;

    var box_main = new Box (Orientation.VERTICAL, 0);
    // TRANSLATORS:
    // E.g.: "Add new file to project (inside 'src/' directory)"
    var desc = ((!directory) ? _("Add new file to project (%s)")
    // TRANSLATORS:
    // E.g.: "Create new subdirectory (inside 'src/' directory)"
                             : _("Create new subdirectory (%s)")).printf (
    // TRANSLATORS:
    // Context: Add new file to project (inside `foobar' directory)
                            (path != null) ? _("inside '%s' directory").printf (path)
                                           : _("inside project root directory"));
    var frame_filename = new Frame (desc);
    var box_filename = new Box (Orientation.VERTICAL, 0);
    frame_filename.add (box_filename);

    var ent_filename_err = new Label ("");
    ent_filename_err.sensitive = false;

    Regex valid_chars = /^[a-z0-9.:_\\\/-]+$/i;  // keep "-" at the end!
    var ent_filename = new Entry.with_inputcheck (ent_filename_err, valid_chars);
    ent_filename.set_placeholder_text (_("filename"));  // this is e.g. not visible

    box_filename.pack_start (ent_filename, false, false);
    box_filename.pack_start (ent_filename_err, false, false);
    box_main.pack_start (frame_filename, true, true);
    box_main.show_all();
    dlg.get_content_area().pack_start (box_main);

    string basepath;
    if (path == null)
        basepath = project.project_path;
    else
        basepath = project.get_absolute_path (path);

    string? filename = null;
    dlg.response.connect ((response_id) => {
        if (response_id == ResponseType.ACCEPT) {
            if (ent_filename.text == "") {
                ent_filename.set_label_timer (_("Don't let this field empty. Name a file."), 10);
                return;
            }
            filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                        basepath,
                                        ent_filename.text);
            if (!directory) {
                if (extension != null)
                    if (!filename.has_suffix (@".$extension"))
                        filename += @".$extension";
                var f = File.new_for_path (filename);
                if (!f.query_exists()) {
                    if (f.get_parent() != null && !f.get_parent().query_exists())
                        try {
                            f.get_parent().make_directory_with_parents();
                        } catch (GLib.Error e) {
                            errmsg (_("Could not create parent directory: %s\n"), e.message);
                        }
                    try {
                        f.create (FileCreateFlags.NONE).close();
                    } catch (GLib.IOError e) {
                        errmsg (_("Could not write to new file: %s\n"), e.message);
                        filename = null;
                    } catch (GLib.Error e) {
                        errmsg (_("Could not create new file: %s\n"), e.message);
                        filename = null;
                    }
                }
            } else {
                var f = File.new_for_path (filename);
                if (!f.query_exists())
                    try {
                        f.make_directory_with_parents();
                    } catch (GLib.Error e) {
                        errmsg (_("Could not create new directory: %s\n"), e.message);
                        filename = null;
                    }
            }
        }
        dlg.destroy();
    });
    dlg.run();

    return filename;
}

// vim: set ai ts=4 sts=4 et sw=4
