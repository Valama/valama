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
using Gee;

/**
 * Template selection widget; Can return selected item
 */
public class UiTemplateSelector : TemplatePage {
    private TreeView tree_view;
    private ProjectTemplate[] available_templates;
    private ToggleToolButton btn_credits;
    private ToggleToolButton btn_vlpinfo;
    private ToggleToolButton btn_info;

    private bool initialized;
    private bool accel_added;
    private bool has_content;

    private Widget tinfo;

    public UiTemplateSelector (string? nextpage = null, string? prevpage = null) {
        if (nextpage != null)
            default_next = nextpage;
        if (prevpage != null)
            default_prev = prevpage;

        description = _("Select template");

        initialized = false;
        var accel_group = new AccelGroup();
        accel_added = false;

        var vbox = new Box (Orientation.VERTICAL, 0);
        vbox.expand = true;

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

        btn_info = new ToggleToolButton();
        btn_info.icon_name = "dialog-information";
        btn_info.sensitive = false;
        btn_info.tooltip_text = _("Template information");
        toolbar.add (btn_info);

        /*
         * If this is needed, both accelerators could be removed and added
         * according to btn_info.active. This is not already done cause of
         * overhead to remove and add accelerators globally but would be only
         * a single code line for each (disconnect_key).
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
                tree_view.grab_focus();
            }

        });

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

        tree_view.row_activated.connect (() => {
            btn_info.active = true;
        });

        /* Take care not to make those global accelerators permanent. */
        this.selected.connect (() => {
            if (!initialized) {
                //TODO: Fill TreeView async.
                init();
            }
            if (!accel_added) {
                window_main.add_accel_group (accel_group);
                accel_added = true;
            }
            Idle.add (() => {
                if (has_content)
                    next (true);
                prev (true);
                tree_view.grab_focus();
                return false;
            });
        });
        this.deselected.connect ((status) => {
            if (accel_added) {
                window_main.remove_accel_group (accel_group);
                accel_added = false;
            }
            btn_info.active = false;
            if (status)
                TemplatePage.template = get_selected_template();
        });

        vbox.show_all();
        this.widget = vbox;
    }

    public override string get_id() {
        return "UiTemplateSelector";
    }

    protected override void init() {
        initialized = true;

        var store = new ListStore (2, typeof (string), typeof (Gdk.Pixbuf));
        tree_view.set_model (store);

        available_templates = load_templates();
        if (available_templates.length == 0)
            return;

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
            has_content = true;

            var strb_tlabel = new StringBuilder();
            if (template.unmet_deps.size > 0)
                strb_tlabel.append ("""<span foreground="grey">""");
            strb_tlabel.append ("<b>" + Markup.escape_text (template.name) + "</b>\n"
                                + Markup.escape_text (template.description));

            if (template.unmet_deps.size > 0) {
                strb_tlabel.append ("\n" + Markup.escape_text (_("Missing packages: ")));
                strb_tlabel.append (Markup.escape_text (template.unmet_deps[0].to_string()));
                if (template.unmet_deps[0].choice != null)
                    foreach (var pkg in template.unmet_deps[0].choice.packages)
                        if (pkg != template.unmet_deps[0])
                            strb_tlabel.append (Markup.escape_text (@", $pkg"));
                for (var i = 1; i < template.unmet_deps.size; ++i) {
                    strb_tlabel.append (Markup.escape_text (@", $(template.unmet_deps[i])"));
                    if (template.unmet_deps[i].choice != null)
                        foreach (var pkg in template.unmet_deps[i].choice.packages)
                            if (pkg != template.unmet_deps[i])
                                strb_tlabel.append (Markup.escape_text (@"/$pkg"));
                }
                strb_tlabel.append ("</span>");
            }
            store.set (iter, 0, strb_tlabel.str, 1, template.icon, -1);

            /* Select first entry */
            if (first_entry) {
                tree_view.get_selection().select_iter(iter);
                first_entry = false;
            }
        }
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
                                  + Markup.escape_text (template.name) + "</span>");
        name_lbl.use_markup = true;
        hbox.pack_start (name_lbl, true, true);

        /* Description. */
        var desc_lbl = new Label ("""<span size="large">"""
                                  + Markup.escape_text (template.description) + "</span>");
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
            longdesc_lbl = new Label ("<i>" + Markup.escape_text (_("no long description")) + "</i>");
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
                                            + Markup.escape_text (auth_str) + "</span>");
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

                var strb_author = new StringBuilder();
                if (author.name != null && author.mail != null)
                    strb_author.append ("<a href=\"mailto:" + Markup.escape_text (author.mail)
                                        + "\">" + Markup.escape_text (author.name) + "</a>");
                else if (author.name != null)
                    strb_author.append (author.name);
                else if (author.mail != null)
                    strb_author.append ("<a href=\"mailto:" + Markup.escape_text (author.mail)
                                        + "\">" + Markup.escape_text (author.mail) + "</a>");
                if (author.comment != null)
                    strb_author.append (Markup.escape_text (@" ($(author.comment))"));
                var credits_author_lbl = new Label (strb_author.str);
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
                                                + Markup.escape_text (_("Supported Vala versions"))
                                                + "</span>");
            detailed_vala_info.use_markup = true;
            detailed_vala_info.halign = Align.START;
            detailed_grid.attach (detailed_vala_info, 0, detailed_line++, 2, 1);

            foreach (var ver in template.versions) {
                string? relation = null;
                string relation_after = "";
                switch (ver.rel) {
                    case VersionRelation.AFTER:
                        // TRANSLATORS: Version relation: X > Y
                        relation = _("after");
                        break;
                    case VersionRelation.SINCE:
                        // TRANSLATORS: Version relation: X >= Y
                        relation = _("since");
                        break;
                    case VersionRelation.UNTIL:
                        // TRANSLATORS: Version relation: X <= Y
                        relation = _("until");
                        break;
                    case VersionRelation.BEFORE:
                        // TRANSLATORS: Version relation: X < Y
                        relation = _("before");
                        break;
                    case VersionRelation.ONLY:
                        // TRANSLATORS: Version relation: X == Y
                        break;
                    case VersionRelation.EXCLUDE:
                        // TRANSLATORS: Version relation: X != Y
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
                var ver_lbl = new Label ("<b>" + Markup.escape_text (ver.version)
                                        + "</b>" + Markup.escape_text (relation_after));
                ver_lbl.use_markup = true;
                ver_lbl.halign = Align.START;
                detailed_grid.attach (ver_lbl, 2, detailed_line++, 1, 1);
            }
        }

        /* Packages. */
        if (template.versions.size > 0)
            detailed_grid.attach (new Label (""), 0, detailed_line++, 2, 1);

        var detailed_pkg_info = new Label ("""<span font_size="large">"""
                                            + Markup.escape_text (_("Packages")) + "</span>");
        detailed_pkg_info.use_markup = true;
        detailed_pkg_info.halign = Align.START;
        detailed_grid.attach (detailed_pkg_info, 0, detailed_line++, 2, 1);

        if (template.vproject.packages.size > 0)
            foreach (var pkg in template.vproject.packages.values) {
                Label pkg_lbl;
                var strb_pkgstr = new StringBuilder();
                if (pkg in template.unmet_deps) {
                    strb_pkgstr.append ("<i>");
                    if (pkg.choice == null)
                        strb_pkgstr.append (Markup.escape_text (pkg.to_string()));
                    else {
                        strb_pkgstr.append (pkg.choice.packages[0].to_string());
                        for (int i = 1; i < pkg.choice.packages.size; ++i)
                            strb_pkgstr.append (Markup.escape_text (@"/$(pkg.choice.packages[i])"));
                    }
                    strb_pkgstr.append ("</i> (" + Markup.escape_text (_("not available")) + ")");
                    pkg_lbl = new Label (strb_pkgstr.str);
                } else {
                    if (pkg.choice == null || pkg.choice.packages.size == 1)
                        strb_pkgstr.append (Markup.escape_text (pkg.to_string()));
                    else {
                        strb_pkgstr.append (Markup.escape_text (pkg.to_string()) + " <i>(");
                        var first = true;
                        foreach (var pkg_choice in pkg.choice.packages)
                            if (pkg != pkg_choice) {
                                if (!first)
                                    strb_pkgstr.append (Markup.escape_text (@"/$pkg_choice"));
                                else {
                                    strb_pkgstr.append (Markup.escape_text (pkg_choice.to_string()));
                                    first = false;
                                }
                            }
                        strb_pkgstr.append (")</i>");
                    }
                    pkg_lbl = new Label (strb_pkgstr.str);
                }
                pkg_lbl.use_markup = true;
                pkg_lbl.halign = Align.START;
                detailed_grid.attach (pkg_lbl, 1, detailed_line++, 1, 1);
            }
        else {
            var pkg_lbl = new Label ("<i>" + Markup.escape_text (_("no package required")) + "</i>");
            pkg_lbl.use_markup = true;
            pkg_lbl.halign = Align.START;
            detailed_grid.attach (pkg_lbl, 1, detailed_line++, 1, 1);
        }

        /* Source files. */
        detailed_grid.attach (new Label (""), 0, detailed_line++, 2, 1);

        var detailed_file_info = new Label ("""<span font_size="large">"""
                                            + Markup.escape_text (_("Source files")) + "</span>");
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
            var s_file_lbl = new Label ("<i>" + Markup.escape_text (_("no source files")) + "</i>");
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
 * No longer needed. Selection is done with {@link WelcomeScreen}.
 *
 * @return Return a {@link ValamaProject} of the created template-based project.
 */
[Deprecated]
public ValamaProject? ui_create_project_dialog() {
    var dlg = new Dialog.with_buttons (_("Choose project template"),
                                       window_main,
                                       DialogFlags.MODAL,
                                       _("_Cancel"),
                                       ResponseType.CANCEL,
                                       _("_Open"),
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
    chooser_target.set_current_folder (Environment.get_current_dir());
    box_main.pack_start (chooser_target, false, false);

    chooser_target.file_set.connect (() => {
        switch (chooser_target.get_file().query_file_type (FileQueryInfoFlags.NONE)) {
            case FileType.REGULAR:
                chooser_target.set_current_folder (Path.get_dirname (chooser_target.get_filename()));
                break;
            case FileType.DIRECTORY:
                chooser_target.set_current_folder (chooser_target.get_filename());
                break;
            default:
                break;
        }
    });

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

        /* Substitutions. */
        var tsh = new TempSubsHelper (template.substitutions, target_folder);
        tsh.substitute();
    } catch (GLib.Error e) {
        errmsg (_("Could not copy templates for new project: %s\n"), e.message);
    }


    ValamaProject? new_proj = null;
    try {
        new_proj = new ValamaProject (Path.build_path (Path.DIR_SEPARATOR_S,
                                                       target_folder,
                                                       project_name + ".vlp"),
                                      null,
                                      true,
                                      false);
        new_proj.project_name = project_name;
        new_proj.save_to_recent();
        new_proj.save_project_file();
    } catch (LoadingError e) {
        errmsg (_("Couldn't load new project: %s\n"), e.message);
    }
    return new_proj;
}


public class TempSubsHelper {
    /**
     * Files with list of substitutions to seek only one time through a file.
     */
    private HashMap<string, ArrayList<TemplateSubstition?>?> acc_subst;

    /**
     * Initialize list of files. To apply substitutions run
     * {@link substitutions}.
     *
     * @param substitutions List of all substitutions.
     * @param basedir Base directory for relative paths.
     */
    public TempSubsHelper (Iterable<TemplateSubstition?> substitutions, string basedir) {
        acc_subst = new HashMap<string, ArrayList<TemplateSubstition?>?>();

        foreach (var sub in substitutions) {
            var target = Path.build_path (Path.DIR_SEPARATOR_S,
                                          basedir,
                                          sub.file);
            var f = File.new_for_path (target);
            if (!f.query_exists()) {
                // TRANSLATORS:
                // Context: "Cannot apply substitution @foobar@ (line) -> 'barfoo'"... or
                //          "Cannot apply substitution @foobar@ -> 'barfoo'"...
                warning_msg (_("Cannot apply substitution '@%s@'%s -> '%s': %s does not exist\n"),
                // TRANSLATORS:
                // Context: "Cannot apply substitution @foobar@->>> (line)<<<- -> 'barfoo'"...
                             sub.match, (sub.line) ? _(" (line)") : "", sub.replace, target);
                continue;
            }

            temp_substitute (sub, f);
        }
    }

    /**
     * Apply substitutions to template code.
     *
     * @param sub Information what to substitute.
     * @param f {@link GLib.File} object to apply substitution to.
     */
    private void temp_substitute (TemplateSubstition sub, File f) {
        string fpath = f.get_path();
        if (fpath == null) {
            warning_msg (_("Could not determine file path: %s\n"), f.get_parse_name());
            return;
        }
        if (f.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
            /* Recursion. */
            try {
                var enumerator = f.enumerate_children ("standard::*", FileQueryInfoFlags.NONE);
                FileInfo info = null;
                while ((info = enumerator.next_file()) != null)
                    temp_substitute (sub, f.resolve_relative_path (info.get_name()));
            } catch (GLib.Error e) {
                warning_msg (_("Could not list or iterate through directory content of '%s': %s\n"),
                             fpath, e.message);
            }
        } else {
            ArrayList<TemplateSubstition?> suba;
            if (acc_subst.has_key (fpath))
                suba = acc_subst.get (fpath);
            else
                suba = new ArrayList<TemplateSubstition?>();
            suba.add (sub);
            acc_subst.set (fpath, suba);
        }
    }

    /**
     * Apply accumulated substitutions to temporary file (.valama-new) then
     * overwrite old file.
     */
    //TODO: Don't do anything where nothing is to substitute.
    public void substitute() {
        foreach (var entry in acc_subst.entries) {
            var filename = entry.key;
            var sublist = entry.value;

            foreach (var sub in sublist)
                debug_msg (_("Substitute: '@%s@'%s -> '%s': %s\n"),
                           sub.match, (sub.line) ? _(" (line)") : "", sub.replace, filename);


            var fi = File.new_for_path (filename);
            FileInputStream fis;
            try {
                fis = fi.read();
            } catch (GLib.Error e) {
                warning_msg (_("Cannot read file '%s': %s\n"), filename, e.message);
                return;
            }

            var filename_new = @"$(filename).valama-new";
            var fo = File.new_for_path (filename_new);
            uint i = 0;
            while (fo.query_exists()) {
                if (i++ == 0)
                    filename_new = filename_new + i.to_string();
                else
                    filename_new = filename_new.slice (0, -1) + i.to_string();
                fo = File.new_for_path (filename_new);
            }

            FileOutputStream fos;
            try {
                fos = fo.create (FileCreateFlags.PRIVATE);
            } catch (GLib.Error e) {
                warning_msg (_("Cannot create temporary file '%s' to apply substitutions: %s\n"),
                             filename_new, e.message);
                try {
                    fis.close();
                } catch (GLib.IOError e) {
                    warning_msg (_("Could not close file descriptor for '%s': %s\n"),
                                 filename, e.message);
                }
                return;
            }

            var dis = new DataInputStream (fis);
            var dos = new DataOutputStream (fos);

            string? line = null;
            try {
                while ((line = dis.read_line()) != null) {
                    try {
                        /* Apply all accumulated substitutions. */
                        foreach (var sub in sublist) {
                            if (!sub.line)
                                line = line.replace (@"@$(sub.match)@", sub.replace);
                            else if (line.index_of (@"@$(sub.match)@") > -1)
                                line = sub.replace;
                        }
                        dos.put_string (line + "\n");
                    } catch (GLib.IOError e) {
                        warning_msg (_("Could not write to temporary file '%s': %s\n"),
                                     filename_new, e.message);
                    }
                 }
            } catch (GLib.IOError e) {
                warning_msg (_("Could not read file '%s' properly: %s\n"), filename, e.message);
            }
            try {
                dos.close();
                fo.move (fi, FileCopyFlags.OVERWRITE);  //TODO: Are timestamps an issue?
            } catch (GLib.IOError e) {
                warning_msg (_("Could not close file descriptor for '%s': %s\n"),
                             filename_new, e.message);
                return;
            } catch (GLib.Error e) {
                warning_msg (_("Could not update file '%s' with '%s' (temporary file may still exist): %s\n"),
                             filename, filename_new, e.message);
            }
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
