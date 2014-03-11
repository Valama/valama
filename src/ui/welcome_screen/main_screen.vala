/*
 * src/ui/welcome_screen/main_screen.vala
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

using Gdk;
using Gee;
using Gtk;

namespace WelcomeScreen {

    protected class MainScreen : TemplatePage {

        public signal void create_button_clicked ();
        public signal void open_button_clicked ();
        public signal void recent_project_selected (string path);

        protected override void clean_up() {
        }

        protected override void build() {

            // Sort recent projects
            var recent_items = new TreeSet<RecentInfo> (cmp_recent_info);
            foreach (var info in recentmgr.get_items())
                recent_items.add (info);

            var box_main = new Box(Orientation.VERTICAL, 20);
            box_main.set_size_request (600,400);

            var list = new Gtk.ListBox ();
            list.row_selected.connect((row)=>{row.activate();}); //TODO: Possibly unnecessary in future GTK versions

            int cnt_added_items = 0;
            foreach (var info in recent_items) {
                // Limit number of shown recent projects
                cnt_added_items ++;
                if (cnt_added_items > 5)
                    break;

                // Grid containing all information about one project
                var grid_project = new Gtk.Grid();

                Label lbl_proj_name = new Label(Markup.escape_text (info.get_display_name()));
                lbl_proj_name.expand = true;
                lbl_proj_name.ellipsize = Pango.EllipsizeMode.END;
                lbl_proj_name.halign = Align.START;
                grid_project.attach (lbl_proj_name, 0,0,1,1);

                // Get project path, ellipsize home directory
                Label lbl_proj_path = new Label(null);
                var uri = info.get_uri_display();
                var home = Environment.get_home_dir();
                if (uri.has_prefix (home))
                    lbl_proj_path.label +=  "<i>" + Markup.escape_text ("~" + uri[home.length:uri.length]) + "</i>";
                else
                    lbl_proj_path.label += "<i>" + Markup.escape_text (uri) + "</i>";
                lbl_proj_path.use_markup = true;
                lbl_proj_path.expand = true;
                lbl_proj_path.ellipsize = Pango.EllipsizeMode.END;
                lbl_proj_path.halign = Align.START;
                lbl_proj_path.sensitive = false;
                grid_project.attach (lbl_proj_path, 0,1,1,1);

                // Show last used date
                var now = new DateTime.now_local();
                var modif_time = new DateTime.now_local ().add_days(-info.get_age());
                var lbl_last_modified = new Label(null);
                if (modif_time.get_year() == now.get_year())
                    lbl_last_modified.label = modif_time.format("%e. %b");
                else
                    lbl_last_modified.label = modif_time.format("%e. %b %Y");
                lbl_last_modified.sensitive = false;

                grid_project.attach (lbl_last_modified, 1,0,1,1);

                var row = new ListBoxRow();
                row.activate.connect (()=>{
                    recent_project_selected (info.get_uri_display());
                });
                row.add (grid_project);
                standardize_listbox_row (row);
                list.add (row);
                list.add (new Separator(Orientation.HORIZONTAL));
            }
            var frame = new Frame(null);
            frame.add (list);
            box_main.pack_start (frame, false, true);
            // Other projects button
            var row = new ListBoxRow();
            row.activate.connect (()=>{
                open_button_clicked();
            });
            var lbl = new Label(_("Other project..."));
            lbl.halign = Align.START;
            row.add (lbl);
            standardize_listbox_row (row);
            list.add (row);


            // Create project button
            frame = new Frame(null);
            list = new Gtk.ListBox ();
            list.row_selected.connect((row)=>{row.activate();}); //TODO: Possibly unnecessary in future GTK versions

            row = new ListBoxRow();
            row.activate.connect (()=>{
                create_button_clicked();
            });
            lbl = new Label(_("Create project"));
            lbl.halign = Align.START;
            row.add (lbl);
            standardize_listbox_row (row);
            list.add (row);

            frame.add(list);
            box_main.pack_start (frame, false, true);

            widget = box_main;
        }

        // Compares two recent projects entries
        private int cmp_recent_info (RecentInfo a, RecentInfo b) {
            if (a.get_modified() == b.get_modified())
                return 0;
            return (a.get_modified() < b.get_modified()) ? 1 : -1;
        }

    }
}

// vim: set ai ts=4 sts=4 et sw=4