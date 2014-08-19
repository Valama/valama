/*
 * src/ui/welcome_screen/create_project_buildsystem.vala
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

    protected class CreateProjectBuildsystem : TemplatePageWithHeader {
        public CreateProjectBuildsystem (ref ProjectCreationInfo info) {
            this.info = info;
            check_btn = new Gtk.CheckButton.with_label (_("make library"));
            go_to_next_clicked.connect (() => { 
                switch (bs) {
                    case "plain":
                        this.info.template.vproject.builder = new BuilderPlain (check_btn.active);
                        break;
                    case "cmake":
                        this.info.template.vproject.builder = new BuilderCMake(check_btn.active);
                        break;
                    case "autotools":
                        this.info.template.vproject.builder = new BuilderAutotools(check_btn.active);
                        break;
                    default:
                        this.info.template.vproject.builder = new BuilderPlain (check_btn.active);
                        bug_msg (_("Buildsystem '%s' not recognized."), bs);
                        break;
                }
                this.info.buildsystem = this.info.template.vproject.builder.get_name_id();
                this.info.make_library = check_btn.active;
            });
        }
        private ProjectCreationInfo info;
        private string bs;
        Gtk.CheckButton check_btn;

        protected override void clean_up() {

        }
        protected override Gtk.Widget build_inner_widget() {
            heading = _("Choose Buildsystem");
            description = _("Choose a buildsystem for current project.");
            BuildSystemTemplate.load_buildsystems (true);
            var frame = new Frame(null);
            var box = new Gtk.Box (Orientation.VERTICAL, 20);
            var list = new Gtk.ListBox ();
            list.row_activated.connect (row => {
                bs = (row.get_child() as Gtk.Label).label;
			});
            var row = new ListBoxRow();
            var lbl = new Label ("plain");
            row.add (lbl);
            list.add (row);
            ListBoxRow? row_selected = null;
            buildsystems.foreach (entry => {
				row = new Gtk.ListBoxRow();
				lbl = new Gtk.Label (entry.key);
				row.add (lbl);
				list.add (row);
                if (row_selected == null && entry.key == info.template.vproject.buildsystem) {
                    row_selected = row;
                    bs = entry.key;
                }
				return true;
			});
            list.select_row (row_selected);
			box.pack_start (list);
			box.pack_start (check_btn);
            check_btn.active = info.template.vproject.library;
            frame.add(box);
            var align = new Alignment (0.5f, 0.1f, 1.0f, 0.0f);
            align.add (frame);
            return align;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
