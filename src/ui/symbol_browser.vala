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
    private ulong build_init_id;

    private bool init_done = false;
    private TreeViewColumn column_sym;
    private uint timer_id;

    private SortType? sort_order = null;
    private int? sort_id = null;

    public SymbolBrowser (ValamaProject? vproject=null) {
        if (vproject != null)
            project = vproject;

        tree_view = new TreeView();

        tree_view.insert_column_with_attributes (-1,
                                                 null,
                                                 new CellRendererPixbuf(),
                                                 "pixbuf",
                                                 3,
                                                 null);

        var column_vissym = new TreeViewColumn.with_attributes (
                                                 _("Symbol"),
                                                 new CellRendererText(),
                                                 "markup",
                                                 5,
                                                 null);
        column_vissym.sort_column_id = 0;
        tree_view.append_column (column_vissym);

        column_sym = new TreeViewColumn.with_attributes (
                                                 null,
                                                 new CellRendererText(),
                                                 "text",
                                                 0,
                                                 null);
        column_sym.visible = false;
        tree_view.append_column (column_sym);

        var column_type = new TreeViewColumn.with_attributes (
                                                 null,
                                                 new CellRendererText(),
                                                 "text",
                                                 1,
                                                 null);
        column_type.visible = false;
        tree_view.append_column (column_type);

        var column_access = new TreeViewColumn();
        column_access.visible = false;
        tree_view.append_column (column_access);

        var column_tooltip = new TreeViewColumn.with_attributes (
                                                 null,
                                                 new CellRendererText(),
                                                 "markup",
                                                 4,
                                                 null);
        column_tooltip.visible = false;
        tree_view.tooltip_column = 4;

        var store = new TreeStore (6, typeof (string), typeof (string), typeof (uint),
                                      typeof (Gdk.Pixbuf),
                                      typeof (string), typeof (string));
        tree_view.set_model (store);
        TreeIter iter;
        store.append (out iter, null);

        tree_view.sensitive = false;

        int state = -1;
        timer_id = Timeout.add (800, () => {
            switch (state) {
                case 0:
                    store.set (iter, 5, "<i>" + Markup.escape_text (_("Loading")) + ".  </i>", -1);
                    ++state;
                    break;
                case 1:
                    store.set (iter, 5, "<i>" + Markup.escape_text (_("Loading")) + ".. </i>", -1);
                    ++state;
                    break;
                case 2:
                    store.set (iter, 5, "<i>" + Markup.escape_text (_("Loading")) + "...</i>", -1);
                    ++state;
                    break;
                default:
                    store.set (iter, 5, "<i>" + Markup.escape_text (_("Loading")) + "   </i>", -1);
                    state = 0;
                    break;
            }
            return true;
        });

        /*
         * NOTE: Build symbol table after threaded Guanako update has
         *       finished. This might be later than this point, so connect
         *       a single time to this signal.
         */
        build_init_id = project.guanako_update_finished.connect (() => {
            project.disconnect (build_init_id);
            build();
        });

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
                update_needed = true;
        });
        project.notify["add-multiple-files"].connect (() => {
            if (!project.add_multiple_files && update_needed)
                build();
        });
    }

    private int comp_sym (TreeModel model, TreeIter a, TreeIter b) {
        Value a_type;
        Value b_type;
        model.get_value (a, 1, out a_type);
        model.get_value (b, 1, out b_type);
        var ret = symtype_to_int ((string) a_type) - symtype_to_int ((string) b_type);
        if (ret != 0)
            return ret;

        Value a_access;
        Value b_access;
        model.get_value (a, 2, out a_access);
        model.get_value (b, 2, out b_access);
        ret = symaccess_to_int ((uint) a_access) - symaccess_to_int ((uint) b_access);
        if (ret != 0) {
            if (tree_view.get_column (1).sort_order == SortType.ASCENDING)
                return ret;
            else
                return (-1)*ret;
        }

        Value a_str;
        Value b_str;
        model.get_value (a, 0, out a_str);
        model.get_value (b, 0, out b_str);
        ret = strcmp ((string) a_str, (string) b_str);
        if (tree_view.get_column (1).sort_order == SortType.ASCENDING)
            return ret;
        else
            return (-1)*ret;
    }

    private int symtype_to_int (string type) {
        //TODO: Hash table to speed lookup up?
        switch (type) {
            case "Namespace":
                return 0;
            case "Constant":
                return 1;
            case "Enum":
                return 2;
            case "Enum_value":
                return 3;
            case "Error_domain":
                return 4;
            case "Error_code":
                return 5;
            case "Struct":
                return 6;
            case "Interface":
                return 7;
            case "Class":
                return 8;
            case "Property":
                return 9;
            case "Field":
                return 10;
            case "Delegate":
                return 11;
            case "Method":
                return 12;
            case "Signal":
                return 13;
            //TODO; What about CreationMethod?
            default:
                bug_msg (_("No valid type: %s - %s\n"), type, "UiReport.symtype_to_int");
                return -1;
        }
    }

    private int symaccess_to_int (uint access) {
        switch (access) {
            case SymbolAccessibility.INTERNAL:
                return 0;
            case SymbolAccessibility.PRIVATE:
                return 1;
            case SymbolAccessibility.PROTECTED:
                return 2;
            case SymbolAccessibility.PUBLIC:
                return 3;
            default:
                bug_msg (_("No valid type: %u - %s\n"), access, "UiReport.symaccess_to_int");
                return -1;
        }
    }

    public override void build() {
        new Thread<void*> (_("Symbol browser update"), () => {
            update_needed = false;
            debug_msg (_("Run %s update!\n"), get_name());
            var store = new TreeStore (6, typeof (string), typeof (string), typeof (uint),
                                          typeof (Gdk.Pixbuf),
                                          typeof (string), typeof (string));
            store.set_sort_func (5, comp_sym);
            if (sort_order != null && sort_id != null)
                store.set_sort_column_id (sort_id, sort_order);
            else
                store.set_sort_column_id (5, SortType.ASCENDING);

            TreeIter[] iters = new TreeIter[0];

            Guanako.iter_symbol (project.guanako_project.root_symbol, (smb, depth) => {
                if (smb.name != null) {
                    TreeIter next;
                    if (depth == 1)
                        store.append (out next, null);
                    else
                        store.append (out next, iters[depth - 2]);
                    string typename = get_symbol_type_name(smb);
                    store.set (next, 0, smb.name,
                                     1, typename.up(1) + typename.substring(1),
                                     2, (uint) smb.access,
                                     3, get_pixbuf_for_symbol (smb),
                                     4, Markup.escape_text (Guanako.symbolsig_to_string (smb)),
                                     5, Markup.escape_text (Guanako.symbolsig_to_string (smb, null)),
                                     -1);
                    if (iters.length < depth)
                        iters += next;
                    else
                        iters[depth - 1] = next;
                }
                return Guanako.IterCallbackReturns.CONTINUE;
            });

            if (!init_done) {
                init_done = true;
                Source.remove (timer_id);
                tree_view.sensitive = true;
            }
            tree_view.set_model (store);

            debug_msg (_("%s update finished!\n"), get_name());
            return null;
        });
    }
}

// vim: set ai ts=4 sts=4 et sw=4
