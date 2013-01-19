/*
 * src/ui_project_browser.vala
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

public class ProjectBrowser : UiElement {
    private TreeView tree_view;
    public Widget widget;

    private Gee.ArrayList<TreePath> tree_view_expanded;

    public ProjectBrowser (ValamaProject? project = null) {
        if (project != null)
            this.project = project;
        element_name = "ProjectBrowser";

        tree_view = new TreeView();
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
        btn_add.clicked.connect (on_add_button);
        btn_add.sensitive = false;
        toolbar.add (btn_add);

        var btn_rem = new ToolButton (null, null);
        btn_rem.icon_name = "list-remove-symbolic";
        btn_rem.clicked.connect (on_remove_button);
        btn_rem.sensitive = false;
        toolbar.add (btn_rem);

        var vbox = new Box (Orientation.VERTICAL, 0);
        vbox.pack_start (scrw, true, true);
        vbox.pack_start (toolbar, false, true);

        widget = vbox;

        tree_view.row_activated.connect ((path, column) => {
            TreeIter iter;
            if (!tree_view.model.get_iter (out iter, path)) {
                stderr.printf (_("Couldn't get iterator in TreeView: %s\n"), path.to_string());
                stderr.printf (_("Please report a bug!\n"));
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
                            stderr.printf (_("Couldn't get iterator in TreeView: %s\n"), path.to_string());
                            stderr.printf (_("Please report a bug!\n"));
                            return;
                        }
                        tree_view.model.get (iter, 0, out val, 1, out store_type, -1);
                        if (store_type == StoreType.FILE_TREE)
                            break;
                        filepath = Path.build_path (Path.DIR_SEPARATOR_S, val, filepath);
                    }
                    file_selected (Path.build_path (Path.DIR_SEPARATOR_S,
                                                    project.project_path,
                                                    filepath));
                    break;
                case StoreType.FILE_TREE:
                case StoreType.DIRECTORY:
                case StoreType.PACKAGE_TREE:
                    on_add_button();
                    break;
                case StoreType.PACKAGE:
                    break;
                default:
                    stderr.printf (_("Unexpected enum value: %s: %d\n"), "ui_project_browser - row_activated", store_type);
                    stderr.printf (_("Please report a bug!\n"));
                    break;
            }
        });

        tree_view.cursor_changed.connect (() => {
            TreePath path;
            tree_view.get_cursor (out path, null);
            if (path == null) {  // no bug -> focus changed to other widget
                btn_add.sensitive = false;
                btn_rem.sensitive = false;
                return;
            }

            TreeIter iter;
            if (!tree_view.model.get_iter (out iter, path)) {
                stderr.printf (_("Couldn't get iterator in TreeView: %s\n"), path.to_string());
                stderr.printf (_("Please report a bug!\n"));
                return;
            }

            StoreType store_type;
            string val;
            tree_view.model.get (iter, 0, out val, 1, out store_type, -1);

            switch (store_type) {
                case StoreType.PACKAGE_TREE:
                case StoreType.FILE_TREE:
                case StoreType.DIRECTORY:
                    btn_add.sensitive = true;
                    btn_rem.sensitive = false;
                    break;
                case StoreType.PACKAGE:
                case StoreType.FILE:
                    btn_add.sensitive = true;
                    btn_rem.sensitive = true;
                    break;
                default:
                    stderr.printf (_("Unexpected enum value: %s: %d\n"), "ui_project_browser - cursor_changed", store_type);
                    stderr.printf (_("Please report a bug!\n"));
                    btn_add.sensitive = false;
                    btn_rem.sensitive = false;
                    break;
            }
        });
    }

    public signal void file_selected (string filename);

    /**
     * Map path name to {@link Gtk.TreeIter} to build up correctly folded
     * {@link Gtk.TreeView}.
     */
    private Gee.HashMap<string, TreeIter?> pathmap;
    /**
     * Same as {@link pathmap} for build system files.
     */
    private Gee.HashMap<string, TreeIter?> b_pathmap;

    protected override void build() {
#if DEBUG
        stderr.printf (_("Run %s update!\n"), element_name);
#endif
        var store = new TreeStore (2, typeof (string), typeof (int));
        tree_view.set_model (store);

        pathmap = new Gee.HashMap<string, TreeIter?>();
        b_pathmap = new Gee.HashMap<string, TreeIter?>();
        build_file_treestore (_("Sources"), project.files.to_array(), ref store, ref pathmap);
        build_file_treestore (_("Buildsystem files"), project.b_files.to_array(), ref store, ref b_pathmap);
        build_plain_treestore (_("Packages"), project.guanako_project.packages.to_array(), ref store);

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
#if DEBUG
        stderr.printf (_("%s update finished!\n"), element_name);
#endif
    }

    /**
     * Get Vala packages from filenames and sort them.
     */
    private static GLib.List<string>? get_available_packages() {
        GLib.List<string> list = null;
        string[] paths = new string[] {Path.build_path (Path.DIR_SEPARATOR_S, Config.VALA_DATA_DIR + "-" + Config.VALA_VERSION, "vapi"),
                                       Path.build_path (Path.DIR_SEPARATOR_S, Config.VALA_DATA_DIR, "vapi")};
        try {
            foreach (string path in paths) {
                var enumerator = File.new_for_path (path).enumerate_children (FileAttribute.STANDARD_NAME, 0);
                FileInfo file_info;
                while ((file_info = enumerator.next_file()) != null) {
                    var filename = file_info.get_name();
                    if (filename.has_suffix (".vapi"))
                        list.insert_sorted (filename.substring (0, filename.length - 5), strcmp);
                }
            }
        } catch (GLib.Error e) {
            stderr.printf (_("Could not update vapi files: %s\n"), e.message);
            return null;
        }
        return list;
    }

    /**
     * Select Vala packages to add/remove to/from build system (with valac).
     */
    private static string? package_selection_dialog (ValamaProject project) {

        Dialog dlg = new Dialog.with_buttons(_("Select new packages"),
                                            window_main,
                                            DialogFlags.MODAL,
                                            Stock.CANCEL,
                                            ResponseType.REJECT,
                                            Stock.OK,
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
        var avail_packages = get_available_packages();
        var proposed_packages = new string[0];
        foreach (string pkg in avail_packages) {
            if (pkg in project.guanako_project.packages)  //Ignore packages that are already selected
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

        string ret = null;
        if (dlg.run() == ResponseType.ACCEPT) {
            TreeModel mdl;
            var selected_rows = tree_view.get_selection().get_selected_rows (out mdl);
            foreach (TreePath path in selected_rows)
                ret = proposed_packages[path.get_indices()[0]];
        }
        dlg.destroy();
        return ret;
    }

    private void on_add_button() {
        TreePath path;
        tree_view.get_cursor (out path, null);
        if (path == null) {
            stderr.printf (_("Couldn't get current tree path: %s\n"), "ui_project_browser - on_add_button");
            stderr.printf (_("Please report a bug!\n"));
            return;
        }

        TreeIter iter;
        if (!tree_view.model.get_iter (out iter, path)) {
            stderr.printf (_("Couldn't get iterator in TreeView: %s\n"), path.to_string());
            stderr.printf (_("Please report a bug!\n"));
            return;
        }

        StoreType store_type;
        string val;
        tree_view.model.get (iter, 0, out val, 1, out store_type, -1);

        switch (store_type) {
            case StoreType.FILE_TREE:
                var source_file = ui_create_file_dialog (project);
                if (source_file != null) {
                    //TODO: Check if already loaded.
                    project.guanako_project.add_source_file (source_file);
                    on_file_selected (source_file.filename);
                    update();
                }
                break;
            case StoreType.FILE:
            case StoreType.DIRECTORY:
                string filepath = val;
                StoreType stype;
                while (path.up()) {
                    if (!tree_view.model.get_iter (out iter, path)) {
                        stderr.printf (_("Couldn't get iterator in TreeView: %s\n"), path.to_string());
                        stderr.printf (_("Please report a bug!\n"));
                        return;
                    }
                    tree_view.model.get (iter, 0, out val, 1, out stype, -1);
                    if (stype == StoreType.FILE_TREE)
                        break;
                    filepath = Path.build_path (Path.DIR_SEPARATOR_S, val, filepath);
                }
                if (store_type == StoreType.FILE)
                    filepath = Path.get_dirname (filepath);

                var source_file = ui_create_file_dialog (project, filepath);
                if (source_file != null) {
                    //TODO: Check if already loaded.
                    project.guanako_project.add_source_file (source_file);
                    on_file_selected (source_file.filename);
                    update();
                }
                break;
            case StoreType.PACKAGE_TREE:
            case StoreType.PACKAGE:
                var pkg = package_selection_dialog (project);
                if (pkg != null) {
                    string[] missing_packages = project.guanako_project.add_packages (new string[] {pkg}, true);
                    if (missing_packages.length > 0)
                        ui_missing_packages_dialog(missing_packages);
                    update();
                }
                break;
            default:
                stderr.printf (_("Unexpected enum value: %s: %d\n"), "ui_project_browser - add_button", store_type);
                stderr.printf (_("Please report a bug!\n"));
                break;
        }
    }

    private void on_remove_button() {
        TreePath path;
        tree_view.get_cursor (out path, null);
        if (path == null) {
            stderr.printf (_("Couldn't get current tree path: %s\n"), "ui_project_browser - on_remove_button");
            stderr.printf (_("Please report a bug!\n"));
            return;
        }

        TreeIter iter;
        if (!tree_view.model.get_iter (out iter, path)) {
            stderr.printf (_("Couldn't get iterator in TreeView: %s\n"), path.to_string());
            stderr.printf (_("Please report a bug!\n"));
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
                        stderr.printf (_("Couldn't get iterator in TreeView: %s\n"), path.to_string());
                        stderr.printf (_("Please report a bug!\n"));
                        return;
                    }
                    tree_view.model.get (iter, 0, out val, 1, out stype, -1);
                    if (stype == StoreType.FILE_TREE)
                        break;
                    filepath = Path.build_path (Path.DIR_SEPARATOR_S, val, filepath);
                }
                var abs_filepath = Path.build_path (Path.DIR_SEPARATOR_S, project.project_path, filepath);

                if (ui_ask_warning (_("Do you want to delete this file?")) == ResponseType.YES) {
                    var pfile = File.new_for_path (project.project_path);
                    var file = File.new_for_path (abs_filepath);
                    var fname = pfile.get_relative_path (file);
                    window_main.close_srcitem (fname);
                    try {
                        file.delete();
                        project.guanako_project.remove_file (project.guanako_project.get_source_file (abs_filepath));
                        //FIXME: Remove file from project (project.files project.b_files).
                        /*
                         * Not necessary here because pathmap will completely
                         * rebuild. But remove it for future better
                         * implementations.
                         */
                        pathmap.unset (filepath);
                        update();
                    } catch (GLib.Error e) {
                        stderr.printf (_("Unable to delete source file '%s': %s\n"), filepath, e.message);
                    }
                }
                break;
            case StoreType.PACKAGE:
                project.guanako_project.remove_package (val);
                update();
                break;
            default:
                stderr.printf (_("Unexpected enum value: %s: %d\n"), "ui_project_browser - cursor_changed", store_type);
                stderr.printf (_("Please report a bug!\n"));
                break;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
