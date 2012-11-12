/**
 * src/ui_symbol_browser.vala
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

public class symbol_browser {
    public symbol_browser (Guanako.project project) {
        this.project = project;

        tree_view = new TreeView();
        tree_view.insert_column_with_attributes (-1,
                                                 "Symbol",
                                                 new CellRendererText(),
                                                 "text",
                                                 0,
                                                 null);

        tree_view.insert_column_with_attributes (-1,
                                                 "Type",
                                                 new CellRendererText(),
                                                 "text",
                                                 1,
                                                 null);

        build();

        widget = tree_view;
    }

    Guanako.project project;
    TreeView tree_view;
    public Widget widget;

    public void build() {
        var store = new TreeStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        TreeIter[] iters = new TreeIter[0];

        Guanako.iter_symbol (project.root_symbol, (smb, depth) => {
            if (smb.name != null) {
                string tpe = "";
                if (smb is Class)    tpe = "Class";
                if (smb is Method)   tpe = "Method";
                if (smb is Field)    tpe = "Field";
                if (smb is Constant) tpe = "Constant";
                if (smb is Property) tpe = "Property";

                TreeIter next;
                if (depth == 1)
                    store.append (out next, null);
                else
                    store.append (out next, iters[depth - 2]);
                store.set (next, 0, smb.name, 1, tpe, -1);
                if (iters.length < depth)
                    iters += next;
                else
                    iters[depth - 1] = next;
            }
            return Guanako.iter_callback_returns.continue;
        });
    }
}

// vim: set ai ts=4 sts=4 et sw=4
