/*
 * src/ui/project_browser.vala
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

using Gtk;
using Vala;
using GLib;

/**
 * Browse source code.
 */
public class ProjectBrowser : UiElement {
    private TreeView tree_view;

    private Gee.ArrayList<TreePath> tree_view_expanded;

    private bool update_needed = true;

    public ProjectBrowser (ValamaProject? vproject = null) {
        if (vproject != null)
            project = vproject;

        tree_view = new TreeView();
        tree_view.headers_visible = false;
        tree_view.insert_column_with_attributes (-1,
                                                 _("Project"),
                                                 new CellRendererText(),
                                                 "text",
                                                 0,
                                                 null);
        tree_view_expanded = new Gee.ArrayList<TreePath>();
        build();

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);

        var toolbar = new Toolbar();
        toolbar.icon_size = 1;

        var btn_add = new ToolButton (null, null);
        btn_add.icon_name = "list-add-symbolic";
        btn_add.clicked.connect (() => {
            on_add_button();
        });
        btn_add.sensitive = false;
        toolbar.add (btn_add);

        var btn_rem = new ToolButton (null, null);
        btn_rem.icon_name = "list-remove-symbolic";
        btn_rem.clicked.connect (on_remove_button);
        btn_rem.sensitive = false;
        toolbar.add (btn_rem);

        var btn_mkdir = new ToolButton (null, null);
        btn_mkdir.icon_name = "folder-symbolic";
        btn_mkdir.clicked.connect (() => {
            on_add_button (true);
        });
        btn_mkdir.sensitive = false;
        btn_mkdir.no_show_all = true;
        toolbar.add (btn_mkdir);

        var toolbar_title = new Toolbar ();
        toolbar_title.get_style_context().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
        var ti_title = new ToolItem();
        var plabel = new Label (project.project_name);
        ti_title.add (plabel);
        toolbar_title.add(ti_title);

        project.notify["project-name"].connect (() => {
            ti_title.remove (plabel);
            plabel = new Label (project.project_name);
            ti_title.add (plabel);
            ti_title.show_all();
        });

        var separator_stretch = new SeparatorToolItem();
        separator_stretch.set_expand (true);
        separator_stretch.draw = false;
        toolbar_title.add (separator_stretch);

        var btnSettings = new Gtk.ToolButton (null, null);
        btnSettings.icon_name = "emblem-system-symbolic";
        toolbar_title.add (btnSettings);
        btnSettings.set_tooltip_text (_("Settings"));
        btnSettings.clicked.connect (() => {
            ui_project_dialog (project);
        });

        var vbox = new Box (Orientation.VERTICAL, 0);
        vbox.pack_start (toolbar_title, false, true);
        vbox.pack_start (scrw, true, true);
        vbox.pack_start (toolbar, false, true);

        widget = vbox;

        tree_view.row_activated.connect ((path, column) => {
            TreeIter iter;
            if (!tree_view.model.get_iter (out iter, path)) {
                bug_msg (_("Could not get iterator in TreeView: %s\n"), path.to_string());
                return;
            }

            StoreType store_type;
            string val;
            tree_view.model.get (iter, 0, out val, 1, out store_type, -1);
            switch (store_type) {
                case StoreType.FILE:
                    string filepath = val;
                    while (path.up()) {
                        if (!tree_view.model.get_iter (out iter, path)) {
                            bug_msg (_("Could not get iterator in TreeView: %s\n"), path.to_string());
                            return;
                        }
                        tree_view.model.get (iter, 0, out val, 1, out store_type, -1);
                        if (store_type == StoreType.FILE_TREE)
                            break;
                        filepath = Path.build_path (Path.DIR_SEPARATOR_S, val, filepath);
                    }
                    file_selected (project.get_absolute_path (filepath));
                    break;
                case StoreType.FILE_TREE:
                case StoreType.DIRECTORY:
                case StoreType.PACKAGE_TREE:
                    on_add_button();
                    break;
                case StoreType.PACKAGE:
                    break;
                default:
                    bug_msg (_("Unexpected enum value: %s: %u\n"),
                             "ui_project_browser - row_activated", store_type);
                    break;
            }
        });

        tree_view.cursor_changed.connect (() => {
            TreePath path;
            tree_view.get_cursor (out path, null);
            if (path == null) {  // no bug -> focus changed to other widget
                btn_add.sensitive = false;
                btn_add.tooltip_text = "";
                btn_rem.sensitive = false;
                btn_rem.tooltip_text = "";
                btn_mkdir.sensitive = false;
                btn_mkdir.tooltip_text = "";
                return;
            }

            TreeIter iter;
            if (!tree_view.model.get_iter (out iter, path)) {
                bug_msg (_("Could not get iterator in TreeView: %s\n"), path.to_string());
                return;
            }

            StoreType store_type;
            string val;
            tree_view.model.get (iter, 0, out val, 1, out store_type, -1);

            switch (store_type) {
                case StoreType.PACKAGE_TREE:
                    btn_add.sensitive = true;
                    btn_add.tooltip_text = _("Add new package");
                    btn_rem.sensitive = false;
                    btn_rem.tooltip_text = "";
                    btn_mkdir.hide();
                    break;
                case StoreType.FILE_TREE:
                case StoreType.DIRECTORY:
                    btn_add.sensitive = true;
                    btn_add.tooltip_text = _("Add new file");
                    btn_rem.sensitive = false;
                    // btn_rem.tooltip_text = _("Remove directory (from disk)");
                    btn_rem.tooltip_text = "";
                    btn_mkdir.sensitive = true;
                    btn_mkdir.tooltip_text = _("Add new directory");
                    btn_mkdir.show();
                    break;
                case StoreType.PACKAGE:
                    btn_add.sensitive = true;
                    btn_add.tooltip_text = _("Add new package");
                    btn_rem.sensitive = true;
                    btn_rem.tooltip_text = _("Remove package");
                    btn_mkdir.hide();
                    break;
                case StoreType.FILE:
                    btn_add.sensitive = true;
                    btn_add.tooltip_text = _("Add new file");
                    btn_rem.sensitive = true;
                    btn_rem.tooltip_text = _("Remove file (from disk)");
                    btn_mkdir.sensitive = true;
                    btn_mkdir.tooltip_text = _("Add new directory");
                    btn_mkdir.show();
                    break;
                default:
                    bug_msg (_("Unexpected enum value: %s: %u\n"),
                             "ui_project_browser - cursor_changed", store_type);
                    btn_add.sensitive = false;
                    btn_add.tooltip_text = "";
                    btn_rem.sensitive = false;
                    btn_rem.tooltip_text = "";
                    btn_mkdir.hide();
                    break;
            }
        });

        this.notify["project"].connect (init);
        init();
    }

    private void init() {
        project.source_files_changed.connect (() => {
            if (!project.add_multiple_files)
                build();
            else
                update_needed = true;;
        });
        project.ui_files_changed.connect (() => {
            if (!project.add_multiple_files)
                build();
            else
                update_needed = true;;
        });
        project.buildsystem_files_changed.connect (() => {
            if (!project.add_multiple_files)
                build();
            else
                update_needed = true;;
        });
        project.data_files_changed.connect (() => {
            if (!project.add_multiple_files)
                build();
            else
                update_needed = true;;
        });
        project.packages_changed.connect (() => {
            if (!project.add_multiple_files)
                build();
            else
                update_needed = true;;
        });
        project.notify["add-multiple-files"].connect (() => {
            if (!project.add_multiple_files && update_needed)
                build();
        });
    }

    public signal void file_selected (string filename);

    /**
     * Map path name to {@link Gtk.TreeIter} to build up correctly folded
     * {@link Gtk.TreeView}.
     */
    private Gee.HashMap<string, TreeIter?> pathmap;
    /**
     * Same as {@link pathmap} for user interface files.
     */
    private Gee.HashMap<string, TreeIter?> u_pathmap;
    /**
     * Same as {@link pathmap} for build system files.
     */
    private Gee.HashMap<string, TreeIter?> b_pathmap;
    /**
     * Same as {@link pathmap} for data files.
     */
    private Gee.HashMap<string, TreeIter?> d_pathmap;

    //TODO: Don't rebuild complete store on update.
    protected override void build() {
        // TRANSLATORS: E.g. "Run project browser update!"
        debug_msg (_("Run %s update!\n"), get_name());
        update_needed = false;

        var store = new TreeStore (2, typeof (string), typeof (int));
        tree_view.set_model (store);

        pathmap = new Gee.HashMap<string, TreeIter?>();
        u_pathmap = new Gee.HashMap<string, TreeIter?>();
        b_pathmap = new Gee.HashMap<string, TreeIter?>();
        d_pathmap = new Gee.HashMap<string, TreeIter?>();

        build_file_treestore (_("Sources"),
                              project.source_dirs.to_array(),
                              project.files.to_array(),
                              ref store, ref u_pathmap);
        build_file_treestore (_("User interface files"),
                              project.ui_dirs.to_array(),
                              project.u_files.to_array(),
                              ref store, ref pathmap);
        build_file_treestore (_("Build system files"),
                              project.buildsystem_dirs.to_array(),
                              project.b_files.to_array(),
                              ref store, ref b_pathmap);
        // TRANSLATORS:
        // "Data files" means the file is neighter a (Vala) source file nor a
        // a build system file nor a user interface file - it's an other file
        // or data file.
        build_file_treestore (_("Data files"),
                              project.data_dirs.to_array(),
                              project.d_files.to_array(),
                              ref store, ref d_pathmap);
        build_plain_treestore (_("Packages"),
                              project.packages.keys.to_array(),
                              ref store);

        tree_view.row_collapsed.connect ((iter, path) => {
            if (path in tree_view_expanded)
                tree_view_expanded.remove (path);
        });
        tree_view.row_expanded.connect ((iter, path) => {
            if (!(path in tree_view_expanded))
                tree_view_expanded.add (path);
        });

        foreach (var path in tree_view_expanded)
            tree_view.expand_to_path (path);

        // TRANSLATORS: E.g. "Project browser update finished!"
        debug_msg (_("%s update finished!\n"), get_name());
    }

    /**
     * Select Vala packages to add/remove to/from build system (with valac).
     */
    private static string? package_selection_dialog (ValamaProject project) {

        Dialog dlg = new Dialog.with_buttons (_("Select new packages"),
                                              window_main,
                                              DialogFlags.MODAL,
                                              _("_Cancel"),
                                              ResponseType.REJECT,
                                              _("_Ok"),
                                              ResponseType.ACCEPT);

        var tree_view = new TreeView();
        var listmodel = new ListStore (1, typeof (string));
        tree_view.set_model (listmodel);

        tree_view.insert_column_with_attributes (-1,
                                                 _("Packages"),
                                                 new CellRendererText(),
                                                 "text",
                                                 0);

        /* TODO: Implement this with checkbutton. */
        var avail_packages = Guanako.get_available_packages();
        var proposed_packages = new string[0];
        foreach (var pkg in avail_packages) {
            if (pkg in project.packages.keys)  //Ignore packages that are already selected
                continue;
            proposed_packages += pkg;
            TreeIter iter;
            listmodel.append (out iter);
            listmodel.set (iter, 0, pkg);
        }

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);
        scrw.show_all();
        dlg.get_content_area().pack_start (scrw);
        dlg.set_default_size (400, 600);

        string? ret = null;
        if (dlg.run() == ResponseType.ACCEPT) {
            TreeModel mdl;
            var selected_rows = tree_view.get_selection().get_selected_rows (out mdl);
            foreach (TreePath path in selected_rows)
                ret = proposed_packages[path.get_indices()[0]];
        }
        dlg.destroy();
        return ret;
    }

    private void on_add_button (bool directory = false) {
        TreePath path;
        tree_view.get_cursor (out path, null);
        if (path == null) {
            // TRANSLATORS: This is a technical information. You might not want
            // to translate "TreePath".
            bug_msg (_("Could not get current TreePath: %s\n"), "ui_project_browser - on_add_button");
            return;
        }

        TreeIter iter;
        if (!tree_view.model.get_iter (out iter, path)) {
            // TRANSLATORS: This is a technical information. You might not want
            // to translate "TreeView".
            bug_msg (_("Could not get iterator in TreeView: %s\n"), path.to_string());
            return;
        }

        StoreType store_type;
        string val;
        tree_view.model.get (iter, 0, out val, 1, out store_type, -1);

        switch (store_type) {
            case StoreType.FILE_TREE:
                string? filename = null;
                switch (path.get_indices()[0]) {
                    case 0:
                        filename = ui_create_file_dialog (null, "vala", directory);
                        project.add_source_file (filename, directory);
                        break;
                    case 1:
                        filename = ui_create_file_dialog (null, null, directory);
                        project.add_ui_file (filename, directory);
                        break;
                    case 2:
                        filename = ui_create_file_dialog (null, null, directory);
                        project.add_buildsystem_file (filename, directory);
                        break;
                    case 3:
                        filename = ui_create_file_dialog (null, null, directory);
                        project.add_data_file (filename, directory);
                        break;
                    default:
                        // TRANSLATORS: This is a technical information. You might not want
                        // to translate "TreePath".
                        bug_msg (_("Unknown TreePath start to add a new file: %s\n"), path.to_string());
                        break;
                }
                if (filename != null && !directory)
                    on_file_selected (filename);
                break;
            case StoreType.FILE:
            case StoreType.DIRECTORY:
                string filepath = val;
                StoreType stype;
                while (path.up()) {
                    if (!tree_view.model.get_iter (out iter, path)) {
                        bug_msg (_("Could not get iterator in TreeView: %s\n"), path.to_string());
                        return;
                    }
                    tree_view.model.get (iter, 0, out val, 1, out stype, -1);
                    if (stype == StoreType.FILE_TREE)
                        break;
                    filepath = Path.build_path (Path.DIR_SEPARATOR_S, val, filepath);
                }
                if (store_type == StoreType.FILE)
                    filepath = Path.get_dirname (filepath);

                string? filename = null;
                switch (path.get_indices()[0]) {
                    case 0:
                        filename = ui_create_file_dialog (filepath, "vala", directory);
                        project.add_source_file (filename, directory);
                        break;
                    case 1:
                        filename = ui_create_file_dialog (filepath, null, directory);
                        project.add_ui_file (filename, directory);
                        break;
                    case 2:
                        filename = ui_create_file_dialog (filepath, null, directory);
                        project.add_buildsystem_file (filename, directory);
                        break;
                    case 3:
                        filename = ui_create_file_dialog (filepath, null, directory);
                        project.add_data_file (filename, directory);
                        break;
                    default:
                        bug_msg (_("Unknown TreePath start to add a new file: %s\n"), path.to_string());
                        break;
                }
                if (filename != null && !directory)
                    on_file_selected (filename);
                break;
            case StoreType.PACKAGE_TREE:
            case StoreType.PACKAGE:
                if (!directory) {
                    var pkg = package_selection_dialog (project);
                    if (pkg != null) {
                        string[]? missing_packages = project.add_package_by_name (pkg);
                        if (missing_packages != null && missing_packages.length > 0)
                            ui_missing_packages_dialog (missing_packages);
                    }
                } else
                    bug_msg (_("Unexpected enum value: %s: %s\n"),
                             "ui_project_browser - add_button", store_type.to_string());
                break;
            default:
                bug_msg (_("Unexpected enum value: %s: %u\n"),
                         "ui_project_browser - add_button", store_type);
                break;
        }
    }

    private void on_remove_button() {
        TreePath path;
        tree_view.get_cursor (out path, null);
        if (path == null) {
            bug_msg (_("Could not get current TreePath: %s\n"), "ui_project_browser - on_remove_button");
            return;
        }

        TreeIter iter;
        if (!tree_view.model.get_iter (out iter, path)) {
            bug_msg (_("Could not get iterator in TreeView: %s\n"), path.to_string());
            return;
        }

        StoreType store_type;
        string val;
        tree_view.model.get (iter, 0, out val, 1, out store_type, -1);

        switch (store_type) {
            case StoreType.PACKAGE_TREE:
            case StoreType.FILE_TREE:
            case StoreType.DIRECTORY:  //TODO: Remove directory.
                break;
            case StoreType.FILE:
                string filepath = val;
                StoreType stype;
                while (path.up()) {
                    if (!tree_view.model.get_iter (out iter, path)) {
                        bug_msg (_("Could not get iterator in TreeView: %s\n"), path.to_string());
                        return;
                    }
                    tree_view.model.get (iter, 0, out val, 1, out stype, -1);
                    if (stype == StoreType.FILE_TREE)
                        break;
                    filepath = Path.build_path (Path.DIR_SEPARATOR_S, val, filepath);
                }
                var abs_filepath = project.get_absolute_path (filepath);
                var rel_filepath = project.get_relative_path (filepath);

                //TODO: Add possibility to only remove file from project.
                if (ui_ask_warning (_("Do you want to delete this file?"),
                                    Markup.escape_text (rel_filepath)) == ResponseType.YES) {
                    var file = File.new_for_path (abs_filepath);
                    source_viewer.close_srcitem (abs_filepath);

                    switch (path.get_indices()[0]) {
                        case 0:
                            project.remove_source_file (abs_filepath);
                            break;
                        case 1:
                            project.remove_ui_file (abs_filepath);
                            break;
                        case 2:
                            project.remove_buildsystem_file (abs_filepath);
                            break;
                        case 3:
                            project.remove_data_file (abs_filepath);
                            break;
                        default:
                            bug_msg (_("Unknown TreePath start to add a new file: %s\n"), path.to_string());
                            break;
                    }
                    /*
                     * Not necessary here because pathmap will completely
                     * rebuild. But remove it for future better
                     * implementations.
                     */
                    //pathmap.unset (filepath);
                    try {
                        //TODO: Backup file?
                        file.delete();
                    } catch (GLib.Error e) {
                        errmsg (_("Unable to delete source file '%s': %s\n"), filepath, e.message);
                    }
                }
                break;
            case StoreType.PACKAGE:
                project.remove_package_by_name (val);
                break;
            default:
                bug_msg (_("Unexpected enum value: %s: %u\n"),
                         "ui_project_browser - cursor_changed", store_type);
                break;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
