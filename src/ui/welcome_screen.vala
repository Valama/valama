/*
 * src/welcome_screen.vala
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

using Gtk;

public class WelcomeScreen : Grid {
    TreeStore store;

    public WelcomeScreen() {
        var box_horiz = new Box (Orientation.HORIZONTAL, 50);
        // box_horiz.homogeneous = true;
        box_horiz.set_size_request (600, 200);

        var tv_recent = new TreeView();
        store = new TreeStore (2, typeof (string), typeof (string));
        tv_recent.set_model (store);
        tv_recent.set_headers_visible (false);
        tv_recent.insert_column_with_attributes (-1,
                                                 "",
                                                 new CellRendererText(),
                                                 "text",
                                                 0,
                                                 null);
        foreach (RecentInfo info in recentmgr.get_items()){
            TreeIter iter;
            store.append(out iter, null);
            store.set (iter, 0, info.get_uri(), 1, info.get_uri(), -1);

        }
        tv_recent.row_activated.connect (on_row_activated);

        box_horiz.pack_start (tv_recent, false, true);

        var box_actions = new Box (Orientation.VERTICAL, 20);

        var btn_create = new Button.with_label("Create new project");
        btn_create.sensitive = false;
        box_actions.pack_start (btn_create, false, true);

        var btn_open = new Button.with_label("Open project");
        btn_open.sensitive = false;
        box_actions.pack_start (btn_open, false, true);
        box_horiz.pack_start (box_actions, true, true);

        var p1 = new Label (""); //Stupid placeholders
        p1.expand = true;
        var p2 = new Label ("");
        p2.expand = true;
        this.attach (p1, 0, 0, 1, 1);
        this.attach (box_horiz, 1, 1, 1, 1);
        this.attach (p2, 2, 2, 1, 1);
        btn_create.clicked.connect (on_create_button_clicked);

        this.show_all();
    }

    void on_create_button_clicked() {
        var proj = ui_create_project_dialog();
        if (proj != null)
            project_loaded (proj);
    }

    void on_row_activated (TreePath path, TreeViewColumn column) {
        TreeIter iter;
        store.get_iter (out iter, path);
        string proj_path;
        store.get (iter, 0, out proj_path);
        try {
            project_loaded (new ValamaProject (proj_path, Args.syntaxfile));
        } catch (LoadingError e) {
            error_msg (_("Could not load new project: %s\n"), e.message);
        }
    }

    public signal void project_loaded(ValamaProject project);

}
