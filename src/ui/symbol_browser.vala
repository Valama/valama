/*
 * src/ui/symbol_browser.vala
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

/**
 * Browser symbols.
 */
public class SymbolBrowser : UiElement {
    TreeView tree_view;
    private bool update_needed = true;

    public SymbolBrowser (ValamaProject? vproject=null) {
        if (vproject != null)
            project = vproject;

        tree_view = new TreeView();
        tree_view.insert_column_with_attributes (-1,
                                                 null,
                                                 new CellRendererPixbuf(),
                                                 "pixbuf",
                                                 2,
                                                 null);

        tree_view.insert_column_with_attributes (-1,
                                                 _("Symbol"),
                                                 new CellRendererText(),
                                                 "text",
                                                 0,
                                                 null);

        tree_view.insert_column_with_attributes (-1,
                                                 _("Type"),
                                                 new CellRendererText(),
                                                 "text",
                                                 1,
                                                 null);

        build();
        //TODO: Is there a better solution to get all symbols?
        project.guanako_update_finished.connect (build_init);

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);

        this.notify["project"].connect (init);
        init();

        widget = scrw;
    }

    private void init() {
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

    private void build_init() {
        project.guanako_update_finished.disconnect (build_init);
        build();
    }

    public override void build() {
        update_needed = false;
        debug_msg (_("Run %s update!\n"), get_name());
        var store = new TreeStore (3, typeof (string), typeof (string), typeof (Gdk.Pixbuf));
        tree_view.set_model (store);

        TreeIter[] iters = new TreeIter[0];

        Guanako.iter_symbol (project.guanako_project.root_symbol, (smb, depth, typename) => {
            if (smb.name != null) {
                string tpe = "";
                foreach (var part in typename.split ("_"))
                    switch (part.length) {
                        case 0:
                            break;
                        case 1:
                            tpe += part.up (1);
                            break;
                        default:
                            tpe += part.up (1) + part.slice (1, part.length);
                            break;
                    }

                TreeIter next;
                if (depth == 1)
                    store.append (out next, null);
                else
                    store.append (out next, iters[depth - 2]);
                store.set (next, 0, smb.name, 1, tpe, 2, get_pixbuf_by_name (typename), -1);
                if (iters.length < depth)
                    iters += next;
                else
                    iters[depth - 1] = next;
            }
            return Guanako.IterCallbackReturns.CONTINUE;
        });
        debug_msg (_("%s update finished!\n"), get_name());
    }
}

// vim: set ai ts=4 sts=4 et sw=4
