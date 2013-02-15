/*
 * src/ui/search.vala
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

/**
 * Search widget
 */
public class UiSearch : UiElement {
    public UiSearch () {
        element_name = "Search";

        tree_view = new TreeView();
        tree_view.insert_column_with_attributes (-1,
                                                 _("Location"),
                                                 new CellRendererText(),
                                                 "text",
                                                 0,
                                                 null);

        tree_view.insert_column_with_attributes (-1,
                                                 _("File"),
                                                 new CellRendererText(),
                                                 "text",
                                                 1,
                                                 null);


        var box_main = new Box (Orientation.VERTICAL, 0);

        var entry_search = new Entry();
        entry_search.changed.connect(() => {
            if (entry_search.text != "")
                search (entry_search.text);
        });
        box_main.pack_start (entry_search, false, true);

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);
        box_main.pack_start (scrw, true, true);

        build();

        widget = box_main;
    }

    TreeView tree_view;
    public Widget widget;

    Thread<void*> search_thread = null;
    bool abort_search_thread = false;
    void search(string search) {
        if (search_thread != null) {
            abort_search_thread = true;
            search_thread.join();
        }
        abort_search_thread = false;
        if (search_thread != null)
            return;
        search_thread = new Thread<void*> (_("Search"), () => {
            var store = new TreeStore (2, typeof (string), typeof (string));
            project.foreach_buffer ((filename, bfr) => {
                TextIter match_start;
                TextIter match_end;
                bfr.get_start_iter(out match_end);
                TreeIter? iter_parent = null;
                while (!abort_search_thread && match_end.forward_search (search, TextSearchFlags.CASE_INSENSITIVE, out match_start, out match_end, null)) {
                    if (iter_parent == null) {
                        store.append (out iter_parent, null);
                        store.set (iter_parent, 0, filename, 1, "", -1);
                    }
                    TreeIter iter_append;
                    store.append (out iter_append, iter_parent);
                    store.set (iter_append, 0, (match_end.get_line() + 1).to_string(), 1, "", -1);
                }
            });
            if (!abort_search_thread)
                GLib.Idle.add (()=> {
                    tree_view.set_model (store);
                    return false;
                });
            search_thread = null;
            return null;
        });
    }

    public override void build() {
        debug_msg (_("Run %s update!\n"), element_name);
        debug_msg (_("%s update finished!\n"), element_name);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
