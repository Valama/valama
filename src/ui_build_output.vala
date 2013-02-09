/*
 * src/ui_build_output.vala
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
    public Widget widget;
    private TextView textview;
    private ProgressBar progressbar;

    public BuildOutput () {
        var vbox = new Box (Orientation.VERTICAL, 0);

        textview = new TextView();
        var scrw = new ScrolledWindow (null, null);
        scrw.add (textview);
        vbox.pack_start (scrw, true, true);

        progressbar = new ProgressBar();
        vbox.pack_start (progressbar, false, false);

        widget = vbox;
        widget.show_all();
        progressbar.visible = false;
        progressbar.halign = Align.START;
        progressbar.set_size_request (200, 0);

        project_builder.buildsys_progress.connect (buildsys_progress);
        project_builder.buildsys_output.connect (buildsys_output);
    }

    public void clear() {
        textview.buffer.text = "";
    }

    private void buildsys_progress (int percent) {
        progressbar.fraction = percent / 100f;
        progressbar.visible = percent != 100;
    }

    private void buildsys_output (string output) {
        textview.buffer.text += output;
    }

    protected override void build() {

    }
}

// vim: set ai ts=4 sts=4 et sw=4
