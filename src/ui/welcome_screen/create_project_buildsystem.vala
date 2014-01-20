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
        }
        private ProjectCreationInfo info;

        protected override void clean_up() {

        }
        protected override Gtk.Widget build_inner_widget() {
            heading = _("Create project");
            description = _("Buildsystem");
            BuildSystemTemplate.load_buildsystems (true);
            var frame = new Frame(null);
            var list = new Gtk.ListBox ();
            list.row_activated.connect (row => {
				string label = (row.get_child() as Gtk.Label).label;
				if (label == "cmake")
					info.template.vproject.builder = new BuilderCMake();
				else
					info.template.vproject.builder = new BuilderAutotools();
			});
            buildsystems.foreach (entry => {
				var row = new Gtk.ListBoxRow();
				var lbl = new Gtk.Label (entry.key);
				row.add (lbl);
				list.add (row);
				return true;
			});
            frame.add(list);
            var align = new Alignment (0.5f, 0.1f, 1.0f, 0.0f);
            align.add (frame);
            return align;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
