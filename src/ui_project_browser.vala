/**
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

public class project_browser {
    public project_browser(valama_project project){
        this.project = project;

        tree_view = new TreeView ();
        tree_view.insert_column_with_attributes (-1, "Project", new CellRendererText (), "text", 0, null);

        build();

        var scrw = new ScrolledWindow(null, null);
        scrw.add(tree_view);
        scrw.set_size_request(200,0);

        var toolbar = new Toolbar();
        toolbar.icon_size = 1;

        var btn_add = new ToolButton(null, null);
        btn_add.icon_name = "list-add-symbolic";
        btn_add.clicked.connect(()=>{
            var pkg = package_selection_dialog(project);
            if (pkg != null){
                project.guanako_project.add_packages(new string[]{pkg});
                packages_changed();
                build();
            }
        });
        toolbar.add(btn_add);

        var btn_rem = new ToolButton(null, null);
        btn_rem.icon_name = "list-remove-symbolic";
        btn_rem.clicked.connect(()=>{
            TreeModel model;
            var paths = tree_view.get_selection().get_selected_rows(out model);
            foreach ( TreePath path in paths){
                var indices = path.get_indices();
                if (indices.length == 2 && indices[0] == 1){
                    project.guanako_project.remove_package(project.guanako_project.packages[indices[1]]);
                    packages_changed();
                    build();
                }
            }
        });
        toolbar.add(btn_rem);

        var vbox = new VBox(false, 0);

        vbox.pack_start(scrw, true, true);
        vbox.pack_start(toolbar, false, true);

        widget = vbox;
    }

    valama_project project;
    TreeView tree_view;
    public Widget widget;

    public signal void source_file_selected(SourceFile file);
    public signal void packages_changed();

    void build(){
        var store = new TreeStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        TreeIter iter_source_files;
        store.append (out iter_source_files, null);
        store.set (iter_source_files, 0, "Sources", -1);

        foreach (SourceFile sf in project.guanako_project.get_source_files()){
            TreeIter iter_sf;
            store.append (out iter_sf, iter_source_files);
            var name = sf.filename.substring(sf.filename.last_index_of("/") + 1);
            store.set (iter_sf, 0, name, 1, "", -1);
        }

        tree_view.row_activated.connect((path)=>{
            int[] indices = path.get_indices();
            if (indices.length > 1){
                if (indices[0] == 0)
                    source_file_selected(project.guanako_project.get_source_files()[indices[1]]);
            }
        });

        TreeIter iter_packages;
        store.append (out iter_packages, null);
        store.set (iter_packages, 0, "Packages", -1);

        foreach (string pkg in project.guanako_project.packages){
            TreeIter iter_sf;
            store.append (out iter_sf, iter_packages);
            store.set (iter_sf, 0, pkg, 1, "", -1);
        }
    }

    /*
     * Get Vala packages from filenames and sort them.
     */
    static GLib.List<string>? get_available_packages() {
        GLib.List<string> list = null;
        /* FIXME: Hardcoded paths. */
        string[] paths = new string[] {"/usr/share/vala-" +
                                       Config.vala_version +
                                       "/vapi",
                                       "/usr/share/vala/vapi"};
        foreach (string path in paths) {
            var enumerator = File.new_for_path (path).enumerate_children (FileAttribute.STANDARD_NAME, 0);
            FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                var filename = file_info.get_name();
                if (filename.has_suffix (".vapi"))
                    list.insert_sorted(filename.substring (0, filename.length - 5), strcmp);
            }
        }
        return list;
    }

    /*
     * Select Vala packages to add/remove to/from build system (with valac).
     */
    static string? package_selection_dialog(valama_project project){

        Dialog dlg = new Dialog.with_buttons("Select new packages",
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
                                                 "Packages",
                                                 new CellRendererText(),
                                                 "text",
                                                 0);

        /* TODO: Implement this with checkbutton. */
        var avail_packages = get_available_packages();
        foreach (string pkg in avail_packages) {
            if (pkg in project.guanako_project.packages) //Ignore packages that are already selected
                continue;
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
                ret = avail_packages.nth_data(path.get_indices()[0]);
        }
        dlg.destroy();
        return ret;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
