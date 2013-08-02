/*
 * src/dialogs/missing_packages.vala
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
using GLib;

/**
 * Show dialog with missing packages.
 */
public void ui_missing_packages_dialog (string[] missing_packages) {
    var dlg_missing_packages = new Dialog.with_buttons (_("Missing packages"),
                                                        window_main,
                                                        DialogFlags.MODAL,
                                                        _("_Ok"),
                                                        ResponseType.OK,
                                                        null);
    dlg_missing_packages.resizable = false;

    var box_main = new Box (Orientation.VERTICAL, 0);
    string dlg = _("The following vala packages are not available on your system:\n");
    foreach (string pkg in missing_packages)
        dlg += pkg + "\n";
    dlg += _("Compiling and auto completion might fail!");
    var lbl_packages = new Label (dlg);
    box_main.pack_start (lbl_packages, true, true);
    box_main.show_all();

    dlg_missing_packages.get_content_area().pack_start (box_main);
    dlg_missing_packages.run();
    dlg_missing_packages.destroy();
}

// vim: set ai ts=4 sts=4 et sw=4
