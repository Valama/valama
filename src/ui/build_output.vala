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

    public BuildOutput() {
        var vbox = new Box (Orientation.VERTICAL, 0);

        textview = new TextView();
        textview.override_font (Pango.FontDescription.from_string ("Monospace 10"));
        textview.editable = false;
        textview.wrap_mode = WrapMode.NONE;

        var scrw = new ScrolledWindow (null, null);
        scrw.add (textview);
        vbox.pack_start (scrw, true, true);

        progressbar = new ProgressBar();
        vbox.pack_start (progressbar, false, true);

        widget = vbox;
        widget.show_all();
        progressbar.visible = false;

        project_builder.build_started.connect (()=> {
            textview.buffer.text = "";
            progressbar.visible = true;
        });
        project_builder.build_finished.connect (()=> {
            progressbar.visible = false;
        });
        project_builder.build_progress.connect (build_progress);
        project_builder.build_output.connect (build_output);
    }

    private void build_progress (int percent) {
        progressbar.fraction = percent / 100f;
    }

    private void build_output (string output) {
        textview.buffer.text += output;
        widget_main.focus_dock_item (this.dock_item);
    }

    protected override void build() {

    }
}

// vim: set ai ts=4 sts=4 et sw=4
