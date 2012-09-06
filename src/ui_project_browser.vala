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

        build();

        var scrw = new ScrolledWindow(null, null);
        scrw.add(tree_view);
        scrw.set_size_request(200,0);
        widget = scrw;
    }

    valama_project project;
    TreeView tree_view;
    public Widget widget;

    public signal void source_file_selected(SourceFile file);

    void build(){
        var store = new TreeStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        tree_view.insert_column_with_attributes (-1, "Project", new CellRendererText (), "text", 0, null);

        TreeIter iter_source_files;
        store.append (out iter_source_files, null);
        store.set (iter_source_files, 0, "Sources", -1);

        foreach (SourceFile sf in project.source_files){
            TreeIter iter_sf;
            store.append (out iter_sf, iter_source_files);
            var name = sf.filename.substring(sf.filename.last_index_of("/") + 1);
            store.set (iter_sf, 0, name, 1, "", -1);
        }

        tree_view.row_activated.connect((path)=>{
            int[] indices = path.get_indices();
            if (indices.length > 1){
                if (indices[0] == 0)
                    source_file_selected(project.source_files[indices[1]]);
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
}

// vim: set ai ts=4 sts=4 et sw=4
