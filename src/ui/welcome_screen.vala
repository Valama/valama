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
using Gdk;

public class WelcomeScreen : Alignment {
    TreeStore store;
    Grid grid_create_project_template;
    Grid grid_create_project_name;
    Grid grid_main;

    public WelcomeScreen() {
        this.xalign = 0.5f;
        this.yalign = 0.5f;
        this.xscale = 0.0f;
        this.yscale = 0.0f;

        grid_main = new Grid();
        grid_main.column_spacing = 30;
        grid_main.row_spacing = 15;
        grid_main.row_homogeneous = false;
        grid_main.column_homogeneous = true;
        grid_main.set_size_request (600, 400);

        var img_valama = new Image.from_pixbuf(new Pixbuf.from_file (Path.build_path (Path.DIR_SEPARATOR_S,
                                                      Config.PACKAGE_DATA_DIR,
                                                      "valama-text.png")));
        grid_main.attach (img_valama, 0, 0, 1, 1);

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
        var scrw = new ScrolledWindow (null, null);
        scrw.add (tv_recent);
        scrw.vexpand = true;

        grid_main.attach (scrw, 0, 1, 1, 3);

        var btn_create = new Button.with_label("Create new project");
        btn_create.clicked.connect(()=>{
            this.remove (grid_main);
            this.add (grid_create_project_template);
        });
        grid_main.attach (btn_create, 1, 1, 1, 1);

        var btn_open = new Button.with_label("Open project");
        btn_open.sensitive = false;
        grid_main.attach (btn_open, 1, 2, 1, 1);

        var p1 = new Label (""); //Stupid placeholder
        p1.vexpand = true;
        grid_main.attach (p1, 1, 3, 1, 1);

        grid_create_project_template = new Grid();
        grid_create_project_template.set_size_request (600, 400);
        var toolbar_template = new Toolbar();
        grid_create_project_template.attach (toolbar_template, 0, 0, 1, 1);
        var btn_template_back = new ToolButton (new Image.from_icon_name ("go-previous-symbolic", IconSize.BUTTON), _("Back"));
        btn_template_back.clicked.connect (()=>{
            this.remove (grid_create_project_template);
            this.add (grid_main);
        });
        toolbar_template.add (btn_template_back);
        var separator2 = new SeparatorToolItem();
        separator2.set_expand (true);
        separator2.draw = false;
        toolbar_template.add (separator2);
        var btn_template_next = new ToolButton (new Image.from_icon_name ("go-next-symbolic", IconSize.BUTTON), _("Next"));
        btn_template_next.clicked.connect (()=>{
            this.remove (grid_create_project_template);
            this.add (grid_create_project_name);
        });
        toolbar_template.add (btn_template_next);

        var template_selector = new UiTemplateSelector();
        template_selector.widget.expand = true;
        grid_create_project_template.attach (template_selector.widget, 0, 1, 1, 1);


        grid_create_project_name = new Grid();
        grid_create_project_name.set_size_request (600, 400);

        var toolbar_name = new Toolbar();
        grid_create_project_name.attach (toolbar_name, 0, 0, 3, 1);
        var btn_name_back = new ToolButton (new Image.from_icon_name ("go-previous-symbolic", IconSize.BUTTON), _("Back"));
        btn_name_back.clicked.connect (()=>{
            this.remove (grid_create_project_name);
            this.add (grid_create_project_template);
        });
        toolbar_name.add (btn_name_back);
        var separator1 = new SeparatorToolItem();
        separator1.set_expand (true);
        separator1.draw = false;
        toolbar_name.add (separator1);
        var btn_name_next = new ToolButton (new Image.from_icon_name ("go-next-symbolic", IconSize.BUTTON), _("Create"));
        btn_name_next.is_important = true;
        toolbar_name.add (btn_name_next);
        toolbar_name.hexpand = true;


        var grid_proj_info = new Grid();
        grid_proj_info.column_spacing = 10;
        grid_proj_info.row_spacing = 15;
        grid_proj_info.row_homogeneous = false;
        grid_proj_info.column_homogeneous = true;
        Regex valid_chars = /^[a-z0-9.:_-]+$/i;  // keep "-" at the end!
        var ent_proj_name_err = new Label ("");
        ent_proj_name_err.sensitive = false;
        var ent_proj_name = new Entry.with_inputcheck (ent_proj_name_err, valid_chars);
        ent_proj_name.set_placeholder_text (_("Project name"));
        var lbl_proj_name = new Label (_("Project name"));
        lbl_proj_name.halign = Align.END;
        grid_proj_info.attach (lbl_proj_name, 0, 2, 1, 1);
        grid_proj_info.attach (ent_proj_name, 1, 2, 1, 1);
        //grid_proj_info.attach (ent_proj_name_err, 1, 3, 1, 1);

        var lbl_proj_location = new Label (_("Location"));
        lbl_proj_location.halign = Align.END;
        grid_proj_info.attach (lbl_proj_location, 0, 4, 1, 1);
        var chooser_location = new FileChooserButton (_("New project location"), Gtk.FileChooserAction.SELECT_FOLDER);
        grid_proj_info.attach (chooser_location, 1, 4, 1, 1);

        btn_name_next.clicked.connect (()=>{
            var target_folder = Path.build_path (Path.DIR_SEPARATOR_S,
                                                chooser_location.get_current_folder(),
                                                ent_proj_name.text);
            var new_project = create_project_from_template (template_selector.get_selected_template(), target_folder, ent_proj_name.text);
            project_loaded (new_project);
            //project_loaded();
        });

        /*var p1 = new Label (""); //Stupid placeholders
        p1.vexpand = true;
        grid_proj_info.attach (p1, 0, 1, 1, 1);
        //lbl_proj_name.hexpand = true;
        var p2 = new Label ("");
        p2.vexpand = true;
        grid_proj_info.attach (p1, 0, 5, 1, 1);*/
        var align_proj_info = new Alignment(0.5f, 0.5f, 0.0f, 0.0f);
        align_proj_info.add (grid_proj_info);

        grid_create_project_name.attach (align_proj_info, 0, 1, 1, 1);

        this.add (grid_main);
        grid_create_project_template.show_all();
        grid_create_project_name.show_all();
        this.show_all();
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
