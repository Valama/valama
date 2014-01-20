/*
 * src/ui/welcome_screen/create_project_location.vala
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


// Project creation: Name and location

using Gtk;

namespace WelcomeScreen {

    // Class to hold all information on the new project across pages
    protected class ProjectCreationInfo {
        public string name = "";
        public string buildsystem = "";
        public bool make_library = false;
        public string directory = "";
        public string[] packages = new string[0];
        public ProjectTemplate template;
    }

    protected class CreateProjectLocation : TemplatePageWithHeader {
        public CreateProjectLocation (ref ProjectCreationInfo info) {
            this.info = info;
        }
        private ProjectCreationInfo info;
        private Entry ent_pname;
        private FileChooserButton chooser_location;
        protected override void clean_up() {
            info.name = ent_pname.text;
            info.directory = Path.build_path (Path.DIR_SEPARATOR_S,
                                     chooser_location.get_filename(),
                                     ent_pname.text);
        }
        protected override Gtk.Widget build_inner_widget() {
            heading = _("Create project");
            description = _("Project settings");
            btn_next.sensitive = false;

            var frame = new Frame(null);
            var list = new Gtk.ListBox ();
            list.selection_mode = SelectionMode.NONE;
            list.row_selected.connect((row)=>{row.activate();}); //TODO: Possibly unnecessary in future GTK versions

            // Project name row
            var row = new ListBoxRow();
            var box = new Box(Orientation.HORIZONTAL, 0);
            var lbl_pname = new Label (_("Project name"));
            lbl_pname.halign = Align.START;
            box.pack_start (lbl_pname, true, true);

            var valid_chars = /^[a-z0-9.:_-]+$/i;  // keep "-" at the end!
            ent_pname = new Entry.with_inputcheck (null, valid_chars);
            ent_pname.set_placeholder_text (_("project name"));
            ent_pname.valid_input.connect (() => {
                btn_next.sensitive = true;
            });
            ent_pname.invalid_input.connect (() => {
                btn_next.sensitive = false;
            });
            box.pack_start (ent_pname, true, true);

            row.add (box);
            standardize_listbox_row (row);
            list.add (row);


            // Project location row
            row = new ListBoxRow();
            box = new Box(Orientation.HORIZONTAL, 0);
            var lbl_plocation = new Label (_("Location"));
            lbl_plocation.halign = Align.START;
            box.pack_start (lbl_plocation, true, true);
            //TODO: Use in place dialog (FileChooserWidget).
            chooser_location = new FileChooserButton (_("New project location"),
                                                          Gtk.FileChooserAction.SELECT_FOLDER);
            chooser_location.set_current_folder (Environment.get_current_dir());

            box.pack_start (chooser_location, true, true);
            row.add (box);
            standardize_listbox_row (row);
            list.add (row);


            frame.add(list);
            var align = new Alignment (0.5f, 0.1f, 1.0f, 0.0f);
            align.add (frame);
            return align;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4