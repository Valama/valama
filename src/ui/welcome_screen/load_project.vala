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


// Open existing project (using a file chooser widget)

using GLib;
using Gtk;
namespace WelcomeScreen {
    public class OpenProject : TemplatePageWithHeader {

        public string? project_filename = "";

        public OpenProject () {
            heading = _("Open project");
            description = _("Select Valama project file");
        }

        protected override void clean_up() {
        }

        protected override Gtk.Widget build_inner_widget() {
            var chooser_open = new FileChooserWidget (FileChooserAction.OPEN);
            chooser_open.expand = true;

            // Only allow .vlp files
            var filter_vlp = new FileFilter();
            filter_vlp.set_filter_name (_("Valama project files (*.vlp)"));
            filter_vlp.add_pattern ("*.vlp");
            chooser_open.add_filter (filter_vlp);
            chooser_open.set_filter (filter_vlp);  // set default filter

            chooser_open.selection_changed.connect (() => {
                project_filename = chooser_open.get_filename();
                btn_next.sensitive = project_filename != null &&
                                     File.new_for_path (project_filename).query_file_type (
                                                    FileQueryInfoFlags.NONE) == FileType.REGULAR;
            });
            chooser_open.file_activated.connect (() => {
                if (btn_next.sensitive) //Only procede if valid file is selected
                    go_to_next_clicked();
            });
            return chooser_open;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4