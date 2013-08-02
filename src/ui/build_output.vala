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
public class BuildOutput : UiElement {
    private TextView textview;
    private ProgressBar progressbar;
    private bool focused;
    private InfoBar info_bar;
    private Label info_label;
    private Image info_icon;

    public BuildOutput() {
        focused = false;

        var vbox = new Box (Orientation.VERTICAL, 0);

        info_bar = new InfoBar();
        info_bar.no_show_all = true;
        var content_area = (Container)info_bar.get_content_area();
        var info_box = new Box(Orientation.HORIZONTAL, 5);
        info_label = new Label("");
        info_icon = new Image();
        info_icon.icon_size = Gtk.IconSize.LARGE_TOOLBAR;
        info_box.pack_start (info_icon, false, true);
        info_box.pack_start (info_label, true, true);
        content_area.add (info_box);
        vbox.pack_start (info_bar, false, true);

        textview = new TextView();
        textview.override_font (Pango.FontDescription.from_string ("Monospace 10"));
        textview.editable = false;
        textview.wrap_mode = WrapMode.NONE;

        var scrw = new ScrolledWindow (null, null);
        scrw.add (textview);
        vbox.pack_start (scrw, true, true);

        double? prev_pos = null;
        textview.size_allocate.connect (() => {
            var adj = scrw.vadjustment;
            if (prev_pos == null || adj.get_value() == prev_pos)
                adj.set_value (adj.upper - adj.page_size);
            prev_pos = adj.upper - adj.page_size;
        });

        progressbar = new ProgressBar();
        vbox.pack_start (progressbar, false, true);
        progressbar.visible = false;
        progressbar.no_show_all = true;

        widget = vbox;
        widget.show_all();

        project_builder.build_started.connect ((clear) => {
            info_bar.no_show_all = false;
            info_bar.show_all();
            info_label.label = _("Running...");
            info_icon.icon_name = "system-run";
            info_bar.set_message_type (MessageType.INFO);

            if (clear) {
                textview.buffer.text = "";
                prev_pos = null;
            }
            focused = false;
            progressbar.visible = true;
        });
        project_builder.build_finished.connect ((success)=> {
            info_bar.no_show_all = false;
            info_bar.show_all();
            focused = false;
            progressbar.visible = false;

            if (success) {
                info_label.label = _("Succeeded");
                info_icon.icon_name = "gtk-ok";
                info_bar.set_message_type (MessageType.INFO);
            } else {
                info_label.label = _("Failed");
                info_icon.icon_name = "dialog-error";
                info_bar.set_message_type (MessageType.ERROR);
            }
        });
        project_builder.build_progress.connect (show_progress);
        project_builder.build_output.connect (show_output);
    }

    private inline void show_progress (int percent) {
        progressbar.fraction = percent / 100f;
    }

    private void show_output (string output) {
        if (!focused) {
            focused = true;
            widget_main.focus_dock_item (this.dock_item);
        }
        textview.buffer.insert_at_cursor (output, -1);
    }

    protected override void build() {}
}

// vim: set ai ts=4 sts=4 et sw=4
