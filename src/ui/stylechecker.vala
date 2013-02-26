/*
 * src/ui/stylechecker.vala
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

using GLib;
using Gtk;

/**
 * Code style checker widget.
 */
public class UiStyleChecker : UiElement {
    TreeView tree_view;

    public UiStyleChecker() {
        tree_view = new TreeView();
        var line_renderer = new CellRendererText();
        line_renderer.yalign = 0;
        tree_view.cursor_changed.connect (on_tree_view_cursor_changed);
        tree_view.insert_column_with_attributes (-1,
                                                 _("Line"),
                                                 line_renderer,
                                                 "text",
                                                 0,
                                                 null);

        tree_view.insert_column_with_attributes (-1,
                                                 "",
                                                 new CellRendererText(),
                                                 "markup",
                                                 1,
                                                 null);


        var box_main = new Box (Orientation.VERTICAL, 0);

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);
        box_main.pack_start (scrw, true, true);

        build();

        widget = box_main;
    }

    public override void build() {
        debug_msg (_("Checker loaded.\n"));
    }

    public void on_tree_view_cursor_changed() {}
}

// vim: set ai ts=4 sts=4 et sw=4
