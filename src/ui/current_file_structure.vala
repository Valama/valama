/*
 * src/ui/current_file_structure.vala
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
using Vala;
using GLib;

/**
 * Show current file's basic structure
 */
public class UiCurrentFileStructure : UiElement {
    public Widget widget;
    TreeView tree_view;
    CheckButton chk_private_symbol;
    Gee.HashMap<string, Symbol> map_iter_symbols = new Gee.HashMap<string, Symbol>();
    TreeStore store;

    public UiCurrentFileStructure () {
        element_name = "CurrentFileStructure";
        var vbox = new Box (Orientation.VERTICAL, 0);

        tree_view = new TreeView();
        var col = new TreeViewColumn();
        tree_view.insert_column (col, -1);
        var pixbuf_renderer = new CellRendererPixbuf();
        col.pack_start (pixbuf_renderer, false);
        col.set_attributes (pixbuf_renderer, "pixbuf", 1);
        var text_renderer = new CellRendererText();
        col.pack_start (text_renderer, true);
        col.set_attributes (text_renderer, "text", 0);
        tree_view.cursor_changed.connect (on_tree_view_cursor_changed);

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);
        vbox.pack_start (scrw, true, true);

        chk_private_symbol = new CheckButton.with_label (_("Private"));
        chk_private_symbol.clicked.connect(() => {
            lock (store)
                build();
        });
        vbox.pack_start (chk_private_symbol, false, true);

        source_viewer.notify["current-srcbuffer"].connect(()=>{
            lock (store)
                build();
        });

        //TODO: Update only on changes.
        Timeout.add_seconds (2, () => {
            /* Lock all store changes to avoid race conditions. */
            lock (store)
                build();
            return false;
        });

        widget = vbox;
    }

    void on_tree_view_cursor_changed() {
        TreePath path;
        tree_view.get_cursor (out path, null);
        if (path == null)
            return;
        Symbol smb = map_iter_symbols[path.to_string()];
        source_viewer.jump_to_position (source_viewer.current_srcfocus, smb.source_reference.begin.line - 1, 0);
    }

    protected override void build() {
        if (source_viewer.current_srcfocus == null)
            return;

        map_iter_symbols = new Gee.HashMap<string, Symbol>();
        store = new TreeStore (2, typeof (string), typeof (Gdk.Pixbuf));
        tree_view.set_model (store);
        var focus_file = project.guanako_project.get_source_file_by_name (source_viewer.current_srcfocus);
        if (focus_file == null)
            return;
        var mark_insert = source_viewer.current_srcbuffer.get_insert();
        TextIter iter;
        source_viewer.current_srcbuffer.get_iter_at_mark (out iter, mark_insert);

        var current_symbol = project.guanako_project.get_symbol_at_pos (focus_file,
                                                                        iter.get_line(),
                                                                        iter.get_line_offset());
        TreeIter? current_iter = null;
        foreach (CodeNode node in focus_file.get_nodes()) {
            if (!(node is Namespace ||
                  node is Class ||
                  node is TypeSymbol ||
                  node is Subroutine ||
                  node is Vala.Signal ||
                  node is Variable ||
                  node is Property))
                continue;

            TreeIter parent;
            store.append (out parent, null);
            store.set (parent, 0, ((Symbol)node).name, 1, get_pixbuf_for_symbol ((Symbol)node), -1);
            map_iter_symbols[store.get_path(parent).to_string()] = (Symbol)node;
            if (node == current_symbol)
                current_iter = parent;

            TreeIter[] iters = new TreeIter[0];
            Guanako.iter_symbol ((Symbol)node, (smb, depth, typename) => {
                if (smb.name != null && (smb is Namespace ||
                                         smb is Class ||
                                         smb is TypeSymbol ||
                                         smb is Subroutine ||
                                         smb is Vala.Signal ||
                                         smb is Variable ||
                                         smb is Property ||
                                         smb is Constant)) {
                    if (smb.access == SymbolAccessibility.PRIVATE && !chk_private_symbol.active)
                        return Guanako.IterCallbackReturns.ABORT_BRANCH;
                    TreeIter next;
                    if (depth == 1)
                        store.append (out next, parent);
                    else
                        store.append (out next, iters[depth - 2]);
                    store.set (next, 0, smb.name, 1, get_pixbuf_by_name (typename), -1);
                    if (smb == current_symbol)
                        current_iter = next;
                    map_iter_symbols[store.get_path(next).to_string()] = smb;
                    if (iters.length < depth)
                        iters += next;
                    else
                        iters[depth - 1] = next;
                    return Guanako.IterCallbackReturns.CONTINUE;
                } else
                    return Guanako.IterCallbackReturns.ABORT_BRANCH;
            });
        }
        tree_view.expand_all();
        if (current_iter != null)
            tree_view.get_selection().select_iter (current_iter);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
