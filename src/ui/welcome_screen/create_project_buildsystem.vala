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

            var grid_pinfo = new Grid();
            grid_pinfo.column_spacing = 10;
            grid_pinfo.row_spacing = 15;
            grid_pinfo.row_homogeneous = false;
            grid_pinfo.column_homogeneous = true;

            var lbl_pname = new Label ("Not implemented yet");
            grid_pinfo.attach (lbl_pname, 0, 0, 1, 1);
            lbl_pname.halign = Align.END;

            return grid_pinfo;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4