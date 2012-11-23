/**
* src/ui_project_dialog.vala
* Copyright (C) 2012, Linus Seelinger <S.Linus@gmx.de>
*               2012, Dominique Lasserre <lasserre.d@gmail.com>
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

/* Load new projects (with dialog). */
public void ui_load_project(project_browser pbrw, symbol_browser smb_browser) {
    var dlg = new FileChooserDialog ("Open project",
                                     window_main,
                                     FileChooserAction.OPEN,
                                     Stock.CANCEL,
                                     ResponseType.CANCEL,
                                     Stock.OPEN,
                                     ResponseType.ACCEPT,
                                     null);
    valama_project new_project;

    var filter_all = new FileFilter();
    filter_all.set_filter_name ("View all files");
    filter_all.add_pattern ("*");

    var filter_vlp = new FileFilter();
    filter_vlp.set_filter_name ("Valama project files");
    filter_vlp.add_pattern ("*.vlp");

    dlg.add_filter (filter_all);
    dlg.add_filter (filter_vlp);
    dlg.set_filter (filter_vlp);  // set default filter

    if (dlg.run() == ResponseType.ACCEPT) {
        //FIXME: Save dialog!
        //TODO: Detect if new project is current project.
        new_project = new valama_project (dlg.get_filename());
        //TODO: Check for failures during new project constructor.
        if (new_project != null) {
            project = new_project;
            //TODO: do that with threads
            pbrw.rebuild (project);
            smb_browser.rebuild (project.guanako_project);
            on_source_file_selected (project.guanako_project.get_source_files()[0]);
        }
        //TODO: Show failure.
    }
    dlg.close();
}

/* Settings window. */
public void ui_project_dialog (valama_project? project) {
    var dlg = new Dialog.with_buttons ("Project settings",
                                       window_main,
                                        DialogFlags.MODAL,
                                        Stock.DISCARD,
                                        ResponseType.REJECT,
                                        Stock.CANCEL,
                                        ResponseType.CANCEL,
                                        Stock.OK,
                                        ResponseType.OK,
                                        null);
    dlg.set_size_request (420, 200);
    dlg.resizable = false;

    var box_main = new Box (Orientation.VERTICAL, 0);

    var frame_project = new Frame ("Project");
    var box_project = new Box (Orientation.VERTICAL, 10);
    frame_project.add (box_project);


    /* Set project name. */
    var box_project_name = new Box (Orientation.VERTICAL, 0);
    box_project_name.pack_start(new Label ("Project name:"), false, false);
    var ent_proj_name_err = new Label ("");
    ent_proj_name_err.sensitive = false;

    Regex valid_chars = /^[a-zA-Z0-9.:_-]+$/;  // keep "-" at the end!
    var ent_proj_name = new Entry.with_inputcheck (ent_proj_name_err, valid_chars, 5);
    ent_proj_name.text = project.project_name;

    box_project_name.pack_start (ent_proj_name, false, false);
    box_project_name.pack_start (ent_proj_name_err, false, false);
    box_project.pack_start (box_project_name, false, false);
    //box_project.pack_start (new Separator(Orientation.HORIZONTAL), false, false);


    /*
     * Set project version.
     * Format: X.Y.Z (major version, minor version, patch version)
     * Restrict major and minor version number to 999 which should be enough.
     */
    var box_version = new Box (Orientation.VERTICAL, 0);
    var box_version_types = new Box (Orientation.HORIZONTAL, 0);
    box_version.pack_start(new Label ("Version:"), false, false);

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
                project.project_name = ent_proj_name.text;
                project.version_major = (int) ent_major.value;
                project.version_minor = (int) ent_minor.value;
                project.version_patch = (int) ent_patch.value;
                //project.version_special = ent_version_special;
                dlg.destroy();
                break;
            case ResponseType.CANCEL:
                dlg.destroy();
                break;
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
                stderr.printf ("Unknown dialog respone id (please report a bug):%d", response_id);
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
