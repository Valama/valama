/*
 * src/dialogs/create_project.vala
 * Copyright (C) 2012, 2013, Valama development team
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

/**
 * Template selection widget; Can return selected item
 */
public class UiTemplateSelector : Object {
    private TreeView tree_view;
    private ProjectTemplate[] available_templates;
    private ToggleToolButton btn_credits;
    private ToggleToolButton btn_vlpinfo;

    private Widget tinfo;

    public Widget widget { get; private set; }

    /**
     * (De)activate signal if template selector is selected by parent widget
     * to activate accels.
     *
     * @param status If true accels will be added to {@link window_main}, if
     *               false disconnect them.
     */
    public signal void selected (bool status);

    public UiTemplateSelector() {
        var accel_group = new AccelGroup();

        var vbox = new Box (Orientation.VERTICAL, 0);
        var infobox = new Box (Orientation.HORIZONTAL, 0);
        vbox.pack_start (infobox, true, true);

        var scrw = new ScrolledWindow (null, null);
        infobox.pack_start (scrw, true, true);

        tree_view = new TreeView();
        scrw.add (tree_view);

        var toolbar = new Toolbar();
        var toolbar_scon = toolbar.get_style_context();
        toolbar_scon.add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
        vbox.pack_end (toolbar, false, false);

        btn_credits = new ToggleToolButton();
        btn_credits.visible = false;
        btn_credits.no_show_all = true;
        btn_credits.icon_name = "user-bookmarks-symbolic";
        toolbar.add (btn_credits);
        btn_credits.tooltip_text = _("Author information");

        btn_vlpinfo = new ToggleToolButton();
        btn_vlpinfo.visible = false;
        btn_vlpinfo.no_show_all = true;
        btn_vlpinfo.icon_name = "emblem-system-symbolic";
        toolbar.add (btn_vlpinfo);
        btn_vlpinfo.tooltip_text = _("Detailed information");

        var separator_expand = new SeparatorToolItem();
        separator_expand.set_expand (true);
        separator_expand.draw = false;
        toolbar.add (separator_expand);

        var btn_info = new ToggleToolButton.from_stock (Stock.INFO);
        btn_info.sensitive = false;
        btn_info.tooltip_text = _("Template information");
        toolbar.add (btn_info);

        /*
         * If this is needed, both accels could be removed and added according
         * to btn_info.active. This is not already done cause of overhead to
         * remove and add accels globally but would be only a single code line
         * for each (disconnect_key).
         */
        accel_group.connect (Gdk.Key.i, 0, 0, () => {
            btn_info.active = true;
            return true;
        });
        accel_group.connect (Gdk.Key.Escape, 0, 0, () => {
            btn_info.active = false;
            return true;
        });

        btn_info.toggled.connect (() => {
            if (btn_info.active) {
                tinfo = show_template_info();
                if (tinfo == null)
                    btn_info.active = false;
                else {
                    infobox.remove (scrw);
                    infobox.pack_start (tinfo, true, true);
                }
            } else {
                infobox.remove (tinfo);
                btn_vlpinfo.visible = false;
                btn_credits.visible = false;
                infobox.pack_start (scrw, true, true);
            }

        });

        var store = new ListStore (2, typeof (string), typeof (Gdk.Pixbuf));
        tree_view.set_model (store);

        tree_view.insert_column_with_attributes (-1,
                                                 null,
                                                 new CellRendererPixbuf(),
                                                 "pixbuf",
                                                 1);
        tree_view.insert_column_with_attributes (-1,
                                                 _("Templates"),
                                                 new CellRendererText(),
                                                 "markup",
                                                 0);

        available_templates = load_templates();

        bool first_entry = true;
        string[] available_packages = new string[0];
        foreach (string av_pkg in Guanako.get_available_packages())
            available_packages += av_pkg;
        foreach (var template in available_templates) {
            TreeIter iter;
            store.append (out iter);

            try {
                template.init (available_packages);
            } catch (LoadingError e) {
                warning_msg (_("Could not load project template: %s\n"), e.message);
                continue;
            }
            btn_info.sensitive = true;

            var template_label = "";
            if (template.unmet_deps.length > 0)
                template_label = """<span foreground="grey">""";
            template_label += "<b>" + template.name + "</b>\n" + template.description;

            if (template.unmet_deps.length > 0) {
                template_label += "\n" + _("Missing packages: ");
                template_label += template.unmet_deps[0];
                for (var i = 1; i < template.unmet_deps.length; ++i)
                    template_label += @", $(template.unmet_deps[i])";
                template_label += "</span>";
            }
            store.set (iter, 0, template_label, 1, template.icon, -1);

            /* Select first entry */
            if (first_entry) {
                tree_view.get_selection().select_iter(iter);
                first_entry = false;
            }
        }

        tree_view.row_activated.connect (() => {
            btn_info.active = true;
        });

        /* Take care not to make those global accels permanent. */
        this.selected.connect ((status) => {
            if (status)
                window_main.add_accel_group (accel_group);
            else
                window_main.remove_accel_group (accel_group);
        });

        this.widget = vbox;
    }

    public ProjectTemplate? get_selected_template() {
        TreeModel model;
        var paths = tree_view.get_selection().get_selected_rows (out model);
        foreach (TreePath path in paths) {
            var indices = path.get_indices();
            return available_templates[indices[0]];
        }
        return null;
    }

    private Widget? show_template_info() {
        var template = get_selected_template();
        if (template == null)
            return null;

        btn_vlpinfo.visible = true;
        btn_vlpinfo.active = false;
        btn_credits.visible = true;
        btn_credits.active = false;

        var vbox = new Box (Orientation.VERTICAL, 10);

        var hbox = new Box (Orientation.HORIZONTAL, 0);
        vbox.pack_start (hbox, false, false);

        /* Icon. */
        var img = new Image.from_pixbuf (template.icon);
        hbox.pack_start (img, false, true);

        /* Name. */
        var name_lbl = new Label ("""<span size="xx-large" font_weight="bold">"""
                                  + template.name + "</span>");
        name_lbl.use_markup = true;
        hbox.pack_start (name_lbl, true, true);

        /* Description. */
        var desc_lbl = new Label ("""<span size="large">"""
                                  + template.description + "</span>");
        desc_lbl.use_markup = true;
        vbox.pack_start (desc_lbl, false, false);

        /* Content area. */
        var hldescbox = new Box (Orientation.HORIZONTAL, 20);
        vbox.pack_start (hldescbox, true, true);

        /* Placeholder left. */
        hldescbox.pack_start (new Box (Orientation.HORIZONTAL, 0), false, true);

        var extrainfo_nbook = new Notebook();
        hldescbox.pack_start (extrainfo_nbook, true, true);
        extrainfo_nbook.show_tabs = false;
        extrainfo_nbook.show_border = false;
        var extrainfo_nbook_max_pages = 0;

        /* Placeholder right. */
        hldescbox.pack_start (new Box (Orientation.HORIZONTAL, 0), false, true);


        /* Long description. */
        var longdesc_scrw = new ScrolledWindow (null, null);
        extrainfo_nbook.append_page (longdesc_scrw);
        longdesc_scrw.border_width = 5;
        longdesc_scrw.shadow_type = ShadowType.IN;

        var longdesc_viewport = new Viewport (null, null);
        longdesc_scrw.add (longdesc_viewport);
        var longdesc_grid = new Grid();
        longdesc_viewport.add (longdesc_grid);
        longdesc_grid.border_width = 5;

        Label longdesc_lbl;
        if (template.long_description != null) {
            longdesc_lbl = new Label (template.long_description);
            longdesc_lbl.selectable = true;
            longdesc_lbl.wrap = true;
        } else
            longdesc_lbl = new Label ("<i>" + _("no long description") + "</i>");
        longdesc_lbl.use_markup = true;
        longdesc_grid.attach (longdesc_lbl, 0, 0, 1, 1);

        /* Credits. */
        if (template.authors.size > 0) {
            var credits_scrw = new ScrolledWindow (null, null);
            extrainfo_nbook.append_page (credits_scrw);
            ++extrainfo_nbook_max_pages;
            credits_scrw.border_width = 5;
            credits_scrw.shadow_type = ShadowType.IN;

            var credits_viewport = new Viewport (null, null);
            credits_scrw.add (credits_viewport);
            var credits_grid = new Grid();
            credits_viewport.add (credits_grid);
            credits_grid.border_width = 50;
            credits_grid.column_spacing = 8;
            credits_grid.row_spacing = 2;

            string auth_str;
            if (template.authors.size == 1)
                auth_str = _("Author");
            else
                auth_str = _("Authors");
            var credits_heading = new Label ("""<span font_weight="bold" font_size="large">"""
                                            + auth_str + "</span>");
            credits_heading.use_markup = true;
            credits_grid.attach (credits_heading, 0, 0, 2, 1);
            credits_heading.halign = Align.START;

            for (int i = 0; i < template.authors.size; ++i) {
                var author = template.authors[i];
                if (author.date != null) {
                    var credits_author_date_lbl = new Label (author.date);
                    credits_grid.attach (credits_author_date_lbl, 1, i+1, 1, 1);
                    credits_author_date_lbl.halign = Align.START;
                }

                string author_string = "";
                if (author.name != null && author.mail != null)
                    author_string = @"<a href=\"mailto:$(author.mail)\">$(author.name)</a>";
                else if (author.name != null)
                    author_string = author.name;
                else if (author.mail != null)
                    author_string = @"<a href=\"mailto:$(author.mail)\">$(author.mail)</a>";
                if (author.comment != null)
                    author_string += @" ($(author.comment))";
                var credits_author_lbl = new Label (author_string);
                credits_author_lbl.use_markup = true;
                credits_grid.attach (credits_author_lbl, 2, i+1, 1, 1);
                credits_author_lbl.halign = Align.START;
            }
        } else
            btn_credits.visible = false;


        /* Template detailed information. */
        var detailed_scrw = new ScrolledWindow (null, null);
        extrainfo_nbook.append_page (detailed_scrw);
        ++extrainfo_nbook_max_pages;
        detailed_scrw.border_width = 5;
        detailed_scrw.shadow_type = ShadowType.IN;

        var detailed_viewport = new Viewport (null, null);
        detailed_scrw.add (detailed_viewport);
        var detailed_grid = new Grid();
        detailed_viewport.add (detailed_grid);
        detailed_grid.border_width = 50;
        detailed_grid.column_spacing = 8;
        detailed_grid.row_spacing = 2;

        int detailed_line = 0;

        /* Vala version. */
        if (template.versions.size > 0) {
            var detailed_vala_info = new Label ("""<span font_size="large">"""
                                                + _("Supported Vala versions") + "</span>");
            detailed_vala_info.use_markup = true;
            detailed_vala_info.halign = Align.START;
            detailed_grid.attach (detailed_vala_info, 0, detailed_line++, 2, 1);

            foreach (var ver in template.versions) {
                string? relation = null;
                string relation_after = "";
                switch (ver.rel) {
                    case VersionRelation.ONLY:
                        break;
                    case VersionRelation.SINCE:
                        relation = _("since");
                        break;
                    case VersionRelation.UNTIL:
                        relation = _("until");
                        break;
                    case VersionRelation.EXCLUDE:
                        relation_after = " " + _("not supported");
                        break;
                    default:
                        bug_msg (_("Unexpected enum value: %s: %d\n"),
                                 "VersionRelation - show_template_info", ver.rel);
                        break;
                }
                if (relation != null) {
                    var ver_rel_lbl = new Label (relation + " ");
                    ver_rel_lbl.halign = Align.END;
                    detailed_grid.attach (ver_rel_lbl, 1, detailed_line, 1, 1);
                }
                var ver_lbl = new Label ("<b>" + ver.version + "</b>" + relation_after);
                ver_lbl.use_markup = true;
                ver_lbl.halign = Align.START;
                detailed_grid.attach (ver_lbl, 2, detailed_line++, 1, 1);
            }
        }

        /* Packages. */
        if (template.versions.size > 0)
            detailed_grid.attach (new Label (""), 0, detailed_line++, 2, 1);

        var detailed_pkg_info = new Label ("""<span font_size="large">"""
                                            + _("Packages") + "</span>");
        detailed_pkg_info.use_markup = true;
        detailed_pkg_info.halign = Align.START;
        detailed_grid.attach (detailed_pkg_info, 0, detailed_line++, 2, 1);

        if (template.packages.length > 0)
            foreach (var pkg in template.packages) {
                Label pkg_lbl;
                if (pkg in template.unmet_deps) {
                    pkg_lbl = new Label ("<i>" + pkg + "</i> (" + _("not available") + ")");
                    pkg_lbl.use_markup = true;
                } else
                    pkg_lbl = new Label (pkg);
                pkg_lbl.halign = Align.START;
                detailed_grid.attach (pkg_lbl, 1, detailed_line++, 1, 1);
            }
        else {
            var pkg_lbl = new Label ("<i>" + _("no package required") + "</i>");
            pkg_lbl.use_markup = true;
            pkg_lbl.halign = Align.START;
            detailed_grid.attach (pkg_lbl, 1, detailed_line++, 1, 1);
        }

        /* Source files. */
        detailed_grid.attach (new Label (""), 0, detailed_line++, 2, 1);

        var detailed_file_info = new Label ("""<span font_size="large">"""
                                            + _("Source files") + "</span>");
        detailed_file_info.use_markup = true;
        detailed_file_info.halign = Align.START;
        detailed_grid.attach (detailed_file_info, 0, detailed_line++, 2, 1);

        if (template.s_files.size > 0)
            foreach (var s_file in template.s_files) {
                var s_file_lbl = new Label (s_file);
                s_file_lbl.halign = Align.START;
                detailed_grid.attach (s_file_lbl, 1, detailed_line++, 1, 1);
            }
        else {
            var s_file_lbl = new Label ("<i>" + _("no source files") + "</i>");
            s_file_lbl.use_markup = true;
            s_file_lbl.halign = Align.START;
            detailed_grid.attach (s_file_lbl, 1, detailed_line++, 1, 1);
        }


        btn_credits.clicked.connect (() => {
            if (btn_credits.active) {
                btn_vlpinfo.active = false;
                extrainfo_nbook.page = 1;
            } else if (!btn_vlpinfo.active)
                extrainfo_nbook.page = 0;
        });
        btn_vlpinfo.clicked.connect (() => {
            if (btn_vlpinfo.active) {
                btn_credits.active = false;
                extrainfo_nbook.page = extrainfo_nbook_max_pages;
            } else if (!btn_credits.active)
                extrainfo_nbook.page = 0;
        });

        vbox.show_all();
        return vbox;
    }
}


/**
 * Project creation dialog.
 *
 * @return Return a {@link ValamaProject} of the created template-based project.
 * @deprecated No longer needed. Selection is done with {@link WelcomeScreen}.
 */
public ValamaProject? ui_create_project_dialog() {
    var dlg = new Dialog.with_buttons (_("Choose project template"),
                                       window_main,
                                       DialogFlags.MODAL,
                                       Stock.CANCEL,
                                       ResponseType.CANCEL,
                                       Stock.OPEN,
                                       ResponseType.ACCEPT,
                                       null);

    dlg.set_size_request (420, 300);
    dlg.resizable = false;

    var selector = new UiTemplateSelector();

    var box_main = new Box (Orientation.VERTICAL, 0);
    box_main.pack_start (selector.widget, true, true);


    var lbl = new Label (_("Project name"));
    lbl.halign = Align.START;
    box_main.pack_start (lbl, false, false);

    var ent_proj_name_err = new Label ("");
    ent_proj_name_err.sensitive = false;

    Regex valid_chars = /^[a-z0-9.:_-]+$/i;  // keep "-" at the end!
    var ent_proj_name = new Entry.with_inputcheck (ent_proj_name_err, valid_chars);
    ent_proj_name.set_placeholder_text (_("Project name"));
    box_main.pack_start (ent_proj_name, false, false);
    box_main.pack_start (ent_proj_name_err, false, false);

    ent_proj_name.valid_input.connect (() => {
        dlg.set_response_sensitive (ResponseType.ACCEPT, true);
    });
    ent_proj_name.invalid_input.connect (() => {
        dlg.set_response_sensitive (ResponseType.ACCEPT, false);
    });


    lbl = new Label (_("Location"));
    lbl.halign = Align.START;
    box_main.pack_start (lbl, false, false);

    var chooser_target = new FileChooserButton (_("New project location"),
                                                Gtk.FileChooserAction.SELECT_FOLDER);
    box_main.pack_start (chooser_target, false, false);

    box_main.show_all();
    dlg.get_content_area().pack_start (box_main);
    dlg.set_response_sensitive (ResponseType.ACCEPT, false);

    var res = dlg.run();
    var template = selector.get_selected_template();
    dlg.destroy();
    if (res == ResponseType.CANCEL || res == ResponseType.DELETE_EVENT || template == null)
        return null;

    string target_folder = Path.build_path (Path.DIR_SEPARATOR_S,
                                            chooser_target.get_current_folder(),
                                            ent_proj_name.text);
    return create_project_from_template (template, target_folder, ent_proj_name.text);
}

public static ValamaProject? create_project_from_template (ProjectTemplate template,
                                                           string target_folder,
                                                           string project_name) {
    try { //TODO: Separate different error catchings to provide differentiate error messages.
        //TODO: Add progress bar and at least warn on overwrite (don't skip
        //      without warning).
        new FileTransfer (template.path,
                          target_folder,
                          CopyRecursiveFlags.SKIP_EXISTENT).copy();
        new FileTransfer (Path.build_path (Path.DIR_SEPARATOR_S,
                                           target_folder,
                                           "template.vlp"),
                          Path.build_path (Path.DIR_SEPARATOR_S,
                                           target_folder,
                                           project_name + ".vlp"),
                          CopyRecursiveFlags.SKIP_EXISTENT).move();

        //TODO: Do this with cmake buildsystem plugin.
        string buildsystem_path;
        if (Args.buildsystemsdir == null)
            buildsystem_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                Config.PACKAGE_DATA_DIR,
                                                "buildsystems",
                                                "cmake",
                                                "buildsystem");
        else
            buildsystem_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                Args.buildsystemsdir,
                                                "cmake",
                                                "buildsystem");
        new FileTransfer (buildsystem_path,
                          target_folder,
                          CopyRecursiveFlags.SKIP_EXISTENT).copy();
        project.save();
    } catch (GLib.Error e) {
        errmsg (_("Could not copy templates for new project: %s\n"), e.message);
    }


    ValamaProject new_proj = null;
    try {
        new_proj = new ValamaProject (Path.build_path (Path.DIR_SEPARATOR_S,
                                                       target_folder,
                                                       project_name + ".vlp"));
        new_proj.project_name = project_name;
    } catch (LoadingError e) {
        errmsg (_("Couln't load new project: %s\n"), e.message);
    }
    return new_proj;
}

// vim: set ai ts=4 sts=4 et sw=4
