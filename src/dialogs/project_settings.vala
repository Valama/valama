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
 * Load new projects (with dialog).
 */
public void ui_load_project() {
    var dlg = new FileChooserDialog (_("Open project"),
                                     window_main,
                                     FileChooserAction.OPEN,
                                     _("_Cancel"),
                                     ResponseType.CANCEL,
                                     _("_Open"),
                                     ResponseType.ACCEPT,
                                     null);
    ValamaProject new_project = null;

    var filter_all = new FileFilter();
    filter_all.set_filter_name (_("View all files (*)"));
    filter_all.add_pattern ("*");

    var filter_vlp = new FileFilter();
    filter_vlp.set_filter_name (_("Valama project files (*.vlp)"));
    filter_vlp.add_pattern ("*.vlp");

    dlg.add_filter (filter_all);
    dlg.add_filter (filter_vlp);
    dlg.set_filter (filter_vlp);  // set default filter

    if (dlg.run() == ResponseType.ACCEPT) {
        var new_filename = dlg.get_filename();
        /*
         * On Unix-like systems compare inodes. On others only compare file names.
         */
#if !UNIX
        if (project.project_file_path != new_filename) {
#else
        //TODO: Check if there is a better solution.
        bool comp;
        try {
            comp = (File.new_for_path (new_filename).query_info (
                            FileAttribute.UNIX_INODE,
                            FileQueryInfoFlags.NONE).get_attribute_as_string (
                                    FileAttribute.UNIX_INODE) !=
                    File.new_for_path (project.project_file_path).query_info (
                            FileAttribute.UNIX_INODE,
                            FileQueryInfoFlags.NONE).get_attribute_as_string (
                                    FileAttribute.UNIX_INODE));
        } catch (GLib.Error e) {
            errmsg (_("Could not compare project files inodes: %s\n"), e.message);
            comp = false;
        }
        if (comp) {
#endif
            if (project != null && !project.close())
                return;
            try {
                new_project = new ValamaProject (new_filename);
            } catch (LoadingError e) {
                errmsg (_("Could not load new project: %s\n"), e.message);
                dlg.close();
                return;
            }
            dlg.close();
            project = new_project;
            on_file_selected (project.guanako_project.get_source_files()[0].filename);
            return;
        } else {
            msg (_("Skip already loaded project: %s\n"), new_filename);
        }
    }
    dlg.close();
}


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
    dlg.set_size_request (420, 200);
    dlg.resizable = false;

    var box_main = new Box (Orientation.VERTICAL, 0);

    var frame_project = new Frame (_("Project"));
    var box_project = new Box (Orientation.VERTICAL, 10);
    frame_project.add (box_project);


    /* Set project name. */
    var box_project_name = new Box (Orientation.VERTICAL, 0);
    box_project_name.pack_start (new Label (_("Project name:")), false, false);
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

    box_project_name.pack_start (ent_proj_name, false, false);
    box_project_name.pack_start (ent_proj_name_err, false, false);
    box_project.pack_start (box_project_name, false, false);
    //box_project.pack_start (new Separator (Orientation.HORIZONTAL), false, false);


    /*
     * Set project version.
     * Format: X.Y.Z (major version, minor version, patch version)
     * Restrict major and minor version number to 999 which should be enough.
     */
    var box_version = new Box (Orientation.VERTICAL, 0);
    var box_version_types = new Box (Orientation.HORIZONTAL, 0);
    box_version.pack_start (new Label (_("Version:")), false, false);

    var ent_major = new SpinButton.with_range (0, 999, 1);
    ent_major.value = (double) project.version_major;
    box_version_types.pack_start (ent_major, false, false);

    var ent_minor = new SpinButton.with_range (0, 999, 1);
    ent_minor.value = (double) project.version_minor;
    box_version_types.pack_start (ent_minor, false, false);

    var ent_patch = new SpinButton.with_range (0, 9999, 1);
    ent_patch.value = (double) project.version_patch;
    box_version_types.pack_start (ent_patch, false, false);

    //TODO: Freely customizable version string (perhaps expert settings?).
    //var ent_version_special = new Entry();
    //ent_version_special.text = project.version_special;
    //box_version_types.pack_start (ent_version_special, false, false);

    box_version.pack_start (box_version_types, false, false);
    box_project.pack_start (box_version, false, false);


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
                //project.version_special = ent_version_special;
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
                break;
            default:
                bug_msg (_("Unexpected enum value: %s: %d\n"), "project_dialog - dlg.response.connect", response_id);
                dlg.destroy();
                break;
        }
    });


    /* Raise window. */
    box_main.pack_start (frame_project, true, true);
    box_main.show_all();

    dlg.get_content_area().pack_start (box_main);
    dlg.run();
}

// vim: set ai ts=4 sts=4 et sw=4
