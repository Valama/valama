/*
 * src/ui_project_browser.vala
 * Copyright (C) 2012, Linus Seelinger <S.Linus@gmx.de>
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
        build();

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);

        var toolbar = new Toolbar();
        toolbar.icon_size = 1;

        var btn_add = new ToolButton (null, null);
        btn_add.icon_name = "list-add-symbolic";
        btn_add.clicked.connect (on_add_button);
        toolbar.add (btn_add);

        var btn_rem = new ToolButton (null, null);
        btn_rem.icon_name = "list-remove-symbolic";
        btn_rem.clicked.connect (on_remove_button);
        toolbar.add (btn_rem);

        var vbox = new Box (Orientation.VERTICAL, 0);
        vbox.pack_start (scrw, true, true);
        vbox.pack_start (toolbar, false, true);

        widget = vbox;
    }

    public signal void source_file_selected (SourceFile file);

    protected override void build() {
#if DEBUG
        stderr.printf (_("Run %s update!\n"), element_name);
#endif
        var store = new TreeStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        TreeIter iter_source_files;
        store.append (out iter_source_files, null);
        store.set (iter_source_files, 0, _("Sources"), -1);

        var pfile = File.new_for_path (project.project_path);
        foreach (SourceFile sf in project.guanako_project.get_source_files()) {
            TreeIter iter_sf;
            store.append (out iter_sf, iter_source_files);
            var name = pfile.get_relative_path (File.new_for_path (sf.filename));
            store.set (iter_sf, 0, name, 1, "", -1);
        }

        tree_view.row_activated.connect ((path) => {
            int[] indices = path.get_indices();
            if (indices.length > 1) {
                if (indices[0] == 0)
                    source_file_selected (project.guanako_project.get_source_files()[indices[1]]);
            }
        });

        TreeIter iter_packages;
        store.append (out iter_packages, null);
        store.set (iter_packages, 0, _("Packages"), -1);

        foreach (string pkg in project.guanako_project.packages) {
            TreeIter iter_sf;
            store.append (out iter_sf, iter_packages);
            store.set (iter_sf, 0, pkg, 1, "", -1);
        }
#if DEBUG
        stderr.printf (_("%s update finished!\n"), element_name);
#endif
    }

    /**
     * Get Vala packages from filenames and sort them.
     */
    private static GLib.List<string>? get_available_packages() {
        GLib.List<string> list = null;
        string[] paths = new string[] {Config.VALA_DATA_DIR + "-" + Config.VALA_VERSION + "/vapi",
                                       Config.VALA_DATA_DIR + "/vapi"};
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
    private static string? package_selection_dialog(ValamaProject project) {

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
        TreeModel model;
        var paths = tree_view.get_selection().get_selected_rows (out model);
        foreach (TreePath path in paths) {
            var indices = path.get_indices();
            /*
             * Allow adding of items also from toplevel trees (don't check
             * indices.length).
             */
            switch (indices[0]) {
                case 0:
                    var source_file = ui_create_file_dialog (project);
                    if (source_file != null) {
                        //TODO: Check if already loaded.
                        project.guanako_project.add_source_file (source_file);
                        on_source_file_selected (source_file);
                        update();
                    }
                    break;
                case 1:
                    var pkg = package_selection_dialog (project);
                    if (pkg != null) {
                        string[] missing_packages = project.guanako_project.add_packages (new string[] {pkg}, true);
                        if (missing_packages.length > 0)
                            ui_missing_packages_dialog(missing_packages);
                        update();
                    }
                    break;
                default:
                    stderr.printf (_("Unexpected enum value: %s: %d\n"), "btn_add.clicked.connect", indices[0]);
                    stderr.printf (_("Please report a bug!"));
                    break;
            }
        }
    }

    private void on_remove_button() {
        TreeModel model;
        var paths = tree_view.get_selection().get_selected_rows (out model);
        foreach (TreePath path in paths) {
            var indices = path.get_indices();
            if (indices.length == 2) {
                switch (indices[0]) {
                    case 0:
                        var source_file = project.guanako_project.get_source_files()[indices[1]];
                        if (project.project_path + "/vapi/config.vapi" == source_file.filename) //Do not delete config.vapi
                            break;
                        if (ui_ask_warning (_("Do you want to delete this file?")) == ResponseType.YES) {
                            var pfile = File.new_for_path (project.project_path);
                            var fname = pfile.get_relative_path (File.new_for_path (source_file.filename));
                            window_main.close_srcitem (fname);
                            try {
                                File.new_for_path (source_file.filename).delete();
                                project.guanako_project.remove_file (source_file);
                                update();
                            } catch (GLib.Error e) {
                                stderr.printf (_("Unable to delete source file: %s\n"), e.message);
                            }
                        }
                        break;
                    case 1:
                        project.guanako_project.remove_package (project.guanako_project.packages[indices[1]]);
                        update();
                        break;
                    default:
                        stderr.printf (_("Unexpected enum value: %s: %d\n"), "btn_rem.clicked.connect", indices[0]);
                        stderr.printf (_("Please report a bug!"));
                        break;
                }
            }
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
