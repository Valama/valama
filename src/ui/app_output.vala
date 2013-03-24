/*
 * src/ui/build_output.vala
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

/**
 * Browse source code.
 */
public class AppOutput : UiElement {
    private TextView textview;
    private bool focused;

    public AppOutput() {
        focused = false;

        var vbox = new Box (Orientation.VERTICAL, 0);

        var toolbar_title = new Toolbar ();
        toolbar_title.get_style_context().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
        var ti_title = new ToolItem();
        var plabel = new Label (_("Application output"));
        ti_title.add (plabel);
        toolbar_title.add(ti_title);

        var separator_stretch = new SeparatorToolItem();
        separator_stretch.set_expand (true);
        separator_stretch.draw = false;
        toolbar_title.add (separator_stretch);

        var btn_clear = new Gtk.ToolButton (null, null);
        btn_clear.icon_name = "edit-clear-all-symbolic";
        toolbar_title.add (btn_clear);
        btn_clear.set_tooltip_text (_("Clear output"));
        btn_clear.clicked.connect (() => {
            textview.buffer.text = "";
        });
        vbox.pack_start (toolbar_title, false, true);

        textview = new TextView();
        textview.override_font (Pango.FontDescription.from_string ("Monospace 10"));
        textview.editable = false;
        textview.wrap_mode = WrapMode.NONE;

        var scrw = new ScrolledWindow (null, null);
        scrw.add (textview);
        vbox.pack_start (scrw, true, true);

        widget = vbox;
        widget.show_all();

        project_builder.notify["app-running"].connect (() => {
            if (project_builder.app_running) {
                if (!focused) {
                    focused = true;
                    widget_main.focus_dock_item (this.dock_item);
                }
                textview.buffer.text = "";
            } else
                focused = false;
        });
        project_builder.app_output.connect (show_output);
    }

    private inline void show_output (string output) {
        textview.buffer.insert_at_cursor (output, -1);
    }

    protected override void build() {}
}

// vim: set ai ts=4 sts=4 et sw=4
