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

using GLib;
using Gtk;
using Gdk;

public class WelcomeScreen : Alignment {
    Grid grid_create_project_template;
    Grid grid_create_project_name;
    Grid grid_open_project;
    Grid grid_main;

    public WelcomeScreen() {
        this.xalign = 0.5f;
        this.yalign = 0.5f;
        this.xscale = 0.0f;
        this.yscale = 0.0f;
        /*stdout.printf (color.red.to_string() + ":" + color.green.to_string() + ":" + color.blue.to_string() + "\n");
        var clr = Gdk.Color(){red = (uint16)(color.red * 256), blue = (uint16)(color.blue * 256), green = (uint16)(color.green * 256)};
        clr = Gdk.Color(){red = 255, blue = 0, green = 255};
        this.modify_bg (StateType.NORMAL, clr);
        this.modify_bg (StateType.ACTIVE, clr);
        this.modify_bg (StateType.INSENSITIVE, clr);
        this.modify_base (StateType.NORMAL, clr);
        this.modify_base (StateType.ACTIVE, clr);
        this.modify_base (StateType.INSENSITIVE, clr);
        this.modify_base (StateType.FOCUSED, clr);
        window_main.override_background_color (StateFlags.NORMAL, color);*/
        //var color = window_main.get_style_context().get_color (StateFlags.BACKDROP);
        //window_main.override_background_color (StateFlags.NORMAL, color);

        /* Initial screen. */
        grid_main = new Grid();
        grid_main.column_spacing = 30;
        grid_main.row_spacing = 15;
        grid_main.row_homogeneous = false;
        grid_main.column_homogeneous = true;
        grid_main.set_size_request (600, 400);

        Image? img_valama = null;
        try {
            img_valama = new Image.from_pixbuf(new Pixbuf.from_file (
                                        Path.build_path (Path.DIR_SEPARATOR_S,
                                                         Config.PACKAGE_DATA_DIR,
                                                         "valama-text.png")));
        } catch (GLib.Error e) {
            errmsg (_("Could not load Valama text logo: %s\n"), e.message);
        }
        grid_main.attach (img_valama, 0, 0, 1, 1);

        /* Recent projects. */
        var grid_recent_projects = new Grid();

        int cnt = 0;
        if (recentmgr.get_items().length() > 0) {
            foreach (RecentInfo info in recentmgr.get_items()){
                var btn_proj = new Button();
                btn_proj.clicked.connect (()=>{
                    try {
                        project_loaded (new ValamaProject (info.get_uri(), Args.syntaxfile));
                    } catch (LoadingError e) {
                        error_msg (_("Could not load new project: %s\n"), e.message);
                    }
                });
                var grid_label = new Grid();
                var lbl_proj_name = new Label ("<b>" + info.get_short_name() + "</b>");
                lbl_proj_name.ellipsize = Pango.EllipsizeMode.END;
                lbl_proj_name.halign = Align.START;
                lbl_proj_name.use_markup = true;
                grid_label.attach (lbl_proj_name, 0, 0, 1, 1);
                var lbl_proj_path = new Label ("<i>" + info.get_uri_display() + "</i>");
                lbl_proj_path.sensitive = false;
                lbl_proj_path.ellipsize = Pango.EllipsizeMode.START;
                lbl_proj_path.halign = Align.START;
                lbl_proj_path.use_markup = true;
                grid_label.attach (lbl_proj_path, 0, 1, 1, 1);
                btn_proj.add (grid_label);
                //lbl_proj_name.expand = false;
                btn_proj.hexpand = true;
                grid_recent_projects.attach (btn_proj, 0, cnt, 1, 1);
                cnt++;
            }
        } else {
            var lbl_no_recent_projects = new Label (_("No recent projects"));
            lbl_no_recent_projects.sensitive = false;
            lbl_no_recent_projects.expand = true;
            grid_recent_projects.attach (lbl_no_recent_projects, 0, 0, 1, 1);
        }
        var scrw = new ScrolledWindow (null, null);
        scrw.add_with_viewport (grid_recent_projects);
        scrw.vexpand = true;
        var lbl_recent_projects = new Label (_("Recent projects"));
        lbl_recent_projects.halign = Align.START;
        lbl_recent_projects.sensitive = false;
        grid_main.attach (lbl_recent_projects, 0, 1, 1, 1);
        grid_main.attach (scrw, 0, 2, 1, 4);

        var btn_create = new Button.with_label(_("Create new project"));
        btn_create.clicked.connect(()=>{
            this.remove (grid_main);
            this.add (grid_create_project_template);
        });
        grid_main.attach (btn_create, 1, 2, 1, 1);

        var btn_open = new Button.with_label(_("Open project"));
        btn_open.clicked.connect(()=>{
            this.remove (grid_main);
            this.add (grid_open_project);
        });
        grid_main.attach (btn_open, 1, 3, 1, 1);

        var p1 = new Label (""); //Stupid placeholder
        p1.vexpand = true;
        grid_main.attach (p1, 1, 4, 1, 1);

        var btn_quit = new Button.with_label(_("Quit"));
        btn_quit.clicked.connect(Gtk.main_quit);
        grid_main.attach (btn_quit, 1, 5, 1, 1);

        project_loaded.connect ((project) => {
            if (project != null) {
                this.forall_internal (false, (child) => {
                    this.remove (child);
                });
                this.add (grid_main);
            }
        });


        /* Project templates. */
        grid_create_project_template = new Grid();
        grid_create_project_template.set_size_request (600, 400);
        var toolbar_template = new Toolbar();
        grid_create_project_template.attach (toolbar_template, 0, 0, 1, 1);
        var btn_template_back = new ToolButton (new Image.from_icon_name (
                                                      "go-previous-symbolic",
                                                      IconSize.BUTTON),
                                                      _("Back"));
        btn_template_back.clicked.connect (()=>{
            this.remove (grid_create_project_template);
            this.add (grid_main);
        });
        toolbar_template.add (btn_template_back);
        var lbl_template_title = new Label ("<b>" + _("Create project")
                                        + "</b>\n" + _("Select template"));
        lbl_template_title.use_markup = true;
        lbl_template_title.justify = Justification.CENTER;
        var ti_template_title = new ToolItem();
        ti_template_title.add (lbl_template_title);
        ti_template_title.set_expand (true);
        toolbar_template.add (ti_template_title);

        var btn_template_next = new ToolButton (new Image.from_icon_name (
                                                      "go-next-symbolic",
                                                      IconSize.BUTTON),
                                                      _("Next"));
        btn_template_next.clicked.connect (()=>{
            this.remove (grid_create_project_template);
            this.add (grid_create_project_name);
        });
        toolbar_template.add (btn_template_next);

        var template_selector = new UiTemplateSelector();
        template_selector.widget.expand = true;
        grid_create_project_template.attach (template_selector.widget, 0, 1, 1, 1);
        grid_create_project_template.notify["parent"].connect (() => {
            if (grid_create_project_template.parent == this)
                template_selector.selected (true);
            else
                template_selector.selected (false);
        });


        grid_create_project_name = new Grid();
        grid_create_project_name.set_size_request (600, 400);

        var toolbar_name = new Toolbar();
        grid_create_project_name.attach (toolbar_name, 0, 0, 3, 1);
        var btn_name_back = new ToolButton (new Image.from_icon_name (
                                                      "go-previous-symbolic",
                                                      IconSize.BUTTON),
                                                      _("Back"));
        btn_name_back.clicked.connect (()=>{
            this.remove (grid_create_project_name);
            this.add (grid_create_project_template);
        });
        toolbar_name.add (btn_name_back);
        var lbl_name_title = new Label ("<b>" + _("Create project")
                                        + "</b>\n" + _("Project info"));
        lbl_name_title.use_markup = true;
        lbl_name_title.justify = Justification.CENTER;
        var ti_name_title = new ToolItem();
        ti_name_title.add (lbl_name_title);
        ti_name_title.set_expand (true);
        toolbar_name.add (ti_name_title);
        var btn_name_next = new ToolButton (new Image.from_icon_name (
                                                      "go-next-symbolic",
                                                      IconSize.BUTTON),
                                                      _("Create"));
        btn_name_next.sensitive = false;
        btn_name_next.is_important = true;
        toolbar_name.add (btn_name_next);
        toolbar_name.hexpand = true;


        /* Project creation details. */
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
        ent_proj_name.valid_input.connect(()=>{
            btn_name_next.sensitive = true;
        });
        ent_proj_name.invalid_input.connect(()=>{
            btn_name_next.sensitive = false;
        });
        var lbl_proj_name = new Label (_("Project name"));
        lbl_proj_name.halign = Align.END;
        grid_proj_info.attach (lbl_proj_name, 0, 2, 1, 1);
        grid_proj_info.attach (ent_proj_name, 1, 2, 1, 1);
        grid_proj_info.attach (ent_proj_name_err, 2, 2, 1, 1);
        //grid_proj_info.attach (ent_proj_name_err, 1, 3, 1, 1);

        var lbl_proj_location = new Label (_("Location"));
        lbl_proj_location.halign = Align.END;
        grid_proj_info.attach (lbl_proj_location, 0, 4, 1, 1);
        var chooser_location = new FileChooserButton (_("New project location"),
                                                      Gtk.FileChooserAction.SELECT_FOLDER);
        grid_proj_info.attach (chooser_location, 1, 4, 1, 1);

        btn_name_next.clicked.connect (()=>{
            var target_folder = Path.build_path (Path.DIR_SEPARATOR_S,
                                                chooser_location.get_current_folder(),
                                                ent_proj_name.text);
            var new_project = create_project_from_template (
                                                template_selector.get_selected_template(),
                                                target_folder,
                                                ent_proj_name.text);
            project_loaded (new_project);
        });

        var align_proj_info = new Alignment(0.5f, 0.5f, 0.0f, 0.0f);
        align_proj_info.expand = true;
        align_proj_info.add (grid_proj_info);

        grid_create_project_name.attach (align_proj_info, 0, 1, 1, 1);


        grid_open_project = new Grid();
        grid_open_project.set_size_request (600, 400);

        var toolbar_open = new Toolbar();
        grid_open_project.attach (toolbar_open, 0, 0, 1, 1);
        var btn_open_back = new ToolButton (new Image.from_icon_name (
                                                "go-previous-symbolic",
                                                IconSize.BUTTON),
                                                _("Back"));
        btn_open_back.clicked.connect (()=>{
            this.remove (grid_open_project);
            this.add (grid_main);
        });
        toolbar_open.add (btn_open_back);
        var lbl_open_title = new Label ("<b>" + _("Open project") + "</b>");
        lbl_open_title.use_markup = true;
        var ti_open_title = new ToolItem();
        ti_open_title.add (lbl_open_title);
        ti_open_title.set_expand (true);
        toolbar_open.add (ti_open_title);
        var btn_open_next = new ToolButton (new Image.from_icon_name (
                                                "go-next-symbolic",
                                                IconSize.BUTTON),
                                                _("Open"));
        var chooser_open = new FileChooserWidget (FileChooserAction.OPEN);
        chooser_open.expand = true;
        grid_open_project.attach (chooser_open, 0, 1, 1, 1);
        var filter_vlp = new FileFilter();
        filter_vlp.set_filter_name (_("Valama project files (*.vlp)"));
        filter_vlp.add_pattern ("*.vlp");
        chooser_open.add_filter (filter_vlp);
        chooser_open.set_filter (filter_vlp);  // set default filter
        chooser_open.selection_changed.connect(()=>{
            var selected_filename = chooser_open.get_filename();
            if (File.new_for_path (selected_filename).query_file_type (
                                                FileQueryInfoFlags.NONE) != FileType.REGULAR)
                btn_open_next.sensitive = false;
            else
                btn_open_next.sensitive = selected_filename.has_suffix (".vlp");
        });
        //btn_open_next.sensitive = false;
        btn_open_next.clicked.connect(()=>{
            try {
                project_loaded (new ValamaProject (chooser_open.get_filename(), Args.syntaxfile));
            } catch (LoadingError e) {
                error_msg (_("Could not load project: %s\n"), e.message);
            }
        });
        btn_open_next.is_important = true;
        toolbar_open.add (btn_open_next);
        toolbar_open.hexpand = true;


        this.add (grid_main);
        grid_create_project_template.show_all();
        grid_create_project_name.show_all();
        grid_open_project.show_all();
        this.show_all();
    }

    public signal void project_loaded (ValamaProject? project);
}

// vim: set ai ts=4 sts=4 et sw=4
