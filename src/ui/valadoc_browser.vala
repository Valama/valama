/*
 * src/ui/structure_view.vala
 * Copyright (C) 2014, Valama development team
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
using WebKit;

public class UiValadocBrowser : UiElement {
    public UiValadocBrowser() {
        var vbox = new Box (Orientation.VERTICAL, 0);

        var sw = new ScrolledWindow (null, null);
        vbox.pack_start (sw, true, true);

        var webview = new WebView();
        webview.load_changed.connect ((event) => {
            if (event == LoadEvent.STARTED && !webview.get_uri().has_prefix ("http://www.valadoc.org/")) {
                webview.stop_loading();
                //TODO: Show visible message.
                debug_msg ("Tried to access content outside of documentation domain: %s\n",
                           webview.get_uri());
            }
        });
        //TODO: Make this configurable.
        webview.load_uri ("http://www.valadoc.org");
        sw.add (webview);

        widget = vbox;
        widget.show_all();
    }

    protected override void build() {}
}

// vim: set ai ts=4 sts=4 et sw=4
