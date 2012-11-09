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

/* Settings window. */
public void ui_project_dialog(valama_project project){
    var dlg = new Dialog.with_buttons("Project settings",
                                    window_main,
                                    DialogFlags.MODAL,
                                    Stock.CANCEL,
                                    ResponseType.CANCEL,
                                    Stock.OK,
                                    ResponseType.OK,
                                    null);
    dlg.set_size_request(400, 200);

    var box_main = new Box(Orientation.VERTICAL, 0);

    var frame_project = new Frame("Project");


    /* Set project name. */
    var box_project = new Box(Orientation.VERTICAL, 0);
    box_project.pack_start(new Label("Name"), false, false);
    var ent_proj_name_err = new Label("");
    var ent_proj_name = new Entry();
    ent_proj_name.text = project.project_name;

    /*
     * Check proper user input. Project names have to consist of "normal"
     * characters only (see regex below). Otherwise cmake would break.
     *
     *TODO: Perhaps we should internally handle special characters with
     *      underscore.
     */
    uint timer_id = 0;  // init timer for help dialog
    Regex valid_char = /^[a-zA-Z0-9.:_-]{1}$/;  // keep "-" at the end!
    MatchInfo match_info = null;  // init to null to make valac happy
    ent_proj_name.insert_text.connect((new_text, new_text_length, position) => {  // TODO: new_text_length and position required?
        if (valid_char.match(new_text, 0, out match_info)) {
            if (timer_id != 0) {
                Source.remove(timer_id);
                timer_id = 0;  // reset to zero to avoid race conditions - TODO: is this necessary?
            }
            ent_proj_name_err.set_label("");
        }
        else {
            ent_proj_name_err.set_label(@"Invalid character: '$(match_info.get_string())' Please choose one from [0-9a-zA-Z.:_-].");
            if (timer_id != 0)
                Source.remove(timer_id);  // reset timer to let it start again
            /* Set timeout of help dialog to 5 seconds. */
            timer_id = Timeout.add_seconds(5, (() => {
                ent_proj_name_err.set_label("");
                return true;
            }));
            Signal.stop_emission_by_name(ent_proj_name, "insert_text");
        }
    });
    /* Clear label if character was deleted. */
    /*FIXME: Code duplication. */
    ent_proj_name.delete_text.connect(() => {
        if (timer_id != 0) {
            Source.remove(timer_id);
            timer_id = 0;  // reset to zero to avoid race conditions - TODO: is this necessary?
        }
        ent_proj_name_err.set_label("");
    });

    box_project.pack_start(ent_proj_name, false, false);
    box_project.pack_start(ent_proj_name_err, false, false);
    frame_project.add(box_project);


    /*
     * Set project version.
     * Format: X.Y.Z (major version, minor version, patch version)
     */
    var box_version = new Box(Orientation.HORIZONTAL, 0);

    var ent_major = new Entry();
    ent_major.text = project.version_major.to_string();
    box_version.pack_start(ent_major, true, true);

    var ent_minor = new Entry();
    ent_minor.text = project.version_minor.to_string();
    box_version.pack_start(ent_minor, true, true);

    var ent_patch = new Entry();
    ent_patch.text = project.version_patch.to_string();
    box_version.pack_start(ent_patch, true, true);

    box_project.pack_start(new Label("Version"), false, false);
    box_project.pack_start(box_version, false, false);


    /* Save changes only when "OK" button is clicked. */
    dlg.response.connect((response_id) => {
        if (response_id == ResponseType.OK) {
            project.project_name = ent_proj_name.text;
            project.version_major = ent_major.text.to_int();
            project.version_minor = ent_minor.text.to_int();
            project.version_patch = ent_patch.text.to_int();
        }
    });


    /* Raise window. */
    box_main.pack_start(frame_project, true, true);
    box_main.show_all();

    dlg.get_content_area().pack_start(box_main);
    dlg.run();
    dlg.destroy();
}
