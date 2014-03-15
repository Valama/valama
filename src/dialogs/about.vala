/*
 * src/dialogs/about.vala
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

using Gtk;
using Gdk;
using GLib;

/**
 * Show about dialog.
 */
public void ui_about_dialog() {
    var dlg = new AboutDialog();
    dlg.resizable = false;

    try {
        dlg.logo = new Pixbuf.from_file (Path.build_path (Path.DIR_SEPARATOR_S,
                                                      Config.PACKAGE_DATA_DIR,
                                                      "valama-text.png"));
    } catch (GLib.Error e) {
        errmsg ("Could not load pixmap: %s\n", e.message);
    }

    //TODO: Generate this automatically from AUTHORS file.
    dlg.artists = null;
    dlg.authors = {"Linus Seelinger <S.Linus@gmx.de>",
                   "Dominique Lasserre <lasserre.d@gmail.com>"};
    dlg.documenters = null;
    dlg.translator_credits =
            "Overscore (%s)".printf (_("French")) + "\n" +
            "Dominique Lasserre <lasserre.d@gmail.com> (%s)".printf (_("German"));

    dlg.program_name = Config.PACKAGE_NAME;
    dlg.comments = _("Next generation Vala IDE");
    dlg.copyright = _("Copyright © 2012, 2013 Valama development team");
    dlg.version  = Config.PACKAGE_VERSION;

    dlg.license_type = License.GPL_3_0;
    dlg.wrap_license = true;

    dlg.website = "https://github.com/Valama/valama";
    dlg.website_label = _("Github project page");

    dlg.response.connect ((response_id) => {
        switch (response_id) {
            case ResponseType.CANCEL:
            case ResponseType.DELETE_EVENT:
                dlg.destroy();
                break;
            default:
                bug_msg (_("Unexpected enum value: %s: %u\n"),
                         "about_dialog - dlg.response.connect", response_id);
                break;
        }
    });

    dlg.run();
}

// vim: set ai ts=4 sts=4 et sw=4
