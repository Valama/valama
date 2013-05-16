/*
 * src/ui/reports.vala
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

using GLib;
using Gtk;
using Gee;
using Guanako;

/**
 * Report build status and code warnings/errors.
 */
class UiReport : UiElement {
    TreeView tree_view = null;
    ScrolledWindow scrw;
    Gdk.Pixbuf pixmap_err;
    Gdk.Pixbuf pixmap_warn;
    Gdk.Pixbuf pixmap_depr;
    Gdk.Pixbuf pixmap_exp;
    Gdk.Pixbuf pixmap_note;

    private ReportType _reptype;
    public ReportType reptype {
        get {
            return _reptype;
        }
        set {
            if (tree_view != null)
                build();
            _reptype = value;
        }
    }

    private bool _showall;
    public bool showall {
        get {
            return _showall;
        }
        set {
            if (tree_view != null)
                scrw.remove (tree_view);

            tree_view = new TreeView();
            tree_view.insert_column_with_attributes (-1,
                                                     null,
                                                     new CellRendererPixbuf(),
                                                     "pixbuf",
                                                     0,
                                                     null);
            if (value)
                tree_view.insert_column_with_attributes (-1,
                                                         _("File"),
                                                         new CellRendererText(),
                                                         "text",
                                                         1,
                                                         null);
            tree_view.insert_column_with_attributes (-1,
                                                     _("Location"),
                                                     new CellRendererText(),
                                                     "text",
                                                     (int) value + 1,
                                                     null);
            tree_view.insert_column_with_attributes (-1,
                                                     _("Error"),
                                                     new CellRendererText(),
                                                     "text",
                                                     (int) value + 2,
                                                     null);
            tree_view.can_focus = false;

            tree_view.row_activated.connect ((path) => {
                int index = path.get_indices()[0];
                var err = storelist[index];

                source_viewer.jump_to_position (err.source.file.filename,
                                                err.source.begin.line - 1,
                                                err.source.begin.column - 1);
                source_viewer.current_srcview.highlight_line (err.source.begin.line - 1);
            });

            scrw.add (tree_view);
            scrw.show_all();

            _showall = value;
            build();

        }
    }

    ArrayList<Reporter.Error> storelist;

    public UiReport (ReportType reptype = ReportType.ALL, bool showall = false) {
        var vbox = new Box (Orientation.VERTICAL, 0);

        scrw = new ScrolledWindow (null, null);
        vbox.pack_start (scrw, true, true);

        this.reptype = reptype;
        this.showall = showall;

        var btn_showall = new CheckButton.with_label (_("Display all"));
        btn_showall.active = showall;
        btn_showall.toggled.connect (() => {
            this.showall = btn_showall.active;
        });
        vbox.pack_start (btn_showall, false, true);

        var w_err = new Invisible();
        pixmap_err = w_err.render_icon (Stock.DIALOG_ERROR, IconSize.MENU, null);
        var w_warn = new Invisible();
        pixmap_warn = w_warn.render_icon (Stock.DIALOG_WARNING, IconSize.MENU, null);
        var w_depr = new Invisible();
        pixmap_depr = w_depr.render_icon (Stock.DIALOG_QUESTION, IconSize.MENU, null);
        var w_exp = new Invisible();
        pixmap_exp = w_exp.render_icon (Stock.ABOUT, IconSize.MENU, null);
        var w_note = new Invisible();
        pixmap_note = w_note.render_icon (Stock.DIALOG_INFO, IconSize.MENU, null);

        project.guanako_update_finished.connect (build);
        source_viewer.current_sourceview_changed.connect (() => {
            if (!this.showall)
                build();
        });

        widget = vbox;
    }

    public override void build() {
        ListStore store;
        if (showall)
            store = new ListStore (4, typeof (Gdk.Pixbuf),typeof (string), typeof (string), typeof (string));
        else
            store = new ListStore (3, typeof (Gdk.Pixbuf), typeof (string), typeof (string));
        tree_view.set_model (store);

        if (!showall && !(source_viewer.current_srcfocus in project.files))
            return;

        debug_msg (_("Run %s update!\n"), get_name());
        storelist = new ArrayList<Reporter.Error>();

        int errs = 0;
        int warns = 0;
        int depr = 0;
        int exp = 0;
        int note = 0;

        foreach (var err in project.get_errorlist()) {
            if ((err.type & reptype) == 0 ||
                    (!showall &&
                     err.source.file.filename != source_viewer.current_srcfocus))
                continue;

            Gdk.Pixbuf? pixbuf = null;
            switch (err.type) {
                case ReportType.ERROR:
                    pixbuf = pixmap_err;
                    ++errs;
                    break;
                case ReportType.WARNING:
                    pixbuf = pixmap_warn;
                    ++warns;
                    break;
                case ReportType.DEPRECATED:
                    pixbuf = pixmap_depr;
                    ++depr;
                    break;
                case ReportType.EXPERIMENTAL:
                    pixbuf = pixmap_exp;
                    ++exp;
                    break;
                case ReportType.NOTE:
                    pixbuf = pixmap_note;
                    ++note;
                    break;
                default:
                    bug_msg (_("Unknown ReportType: %s\n"), err.type.to_string());
                    break;
            }

            TreeIter next;
            store.append (out next);
            if (showall)
                store.set (next,
                           0, pixbuf,
                           1, project.get_relative_path (err.source.file.filename),
                           2, err.source.begin.line.to_string(),
                           3, err.message,
                           -1);
            else
                store.set (next,
                           0, pixbuf,
                           1, err.source.begin.line.to_string(),
                           2, err.message,
                           -1);
            storelist.add (err);
        }

        // TRANSLATORS: Notes aren't notices but comments/remarks.
        debug_msg (_("Errors: %d, Warnings: %d, Deprecated: %d, Experimental: %d, Notes: %d  -  %d\n"),
                   errs,
                   warns,
                   depr,
                   exp,
                   note,
                   project.get_errorlist().size);
        debug_msg (_("%s update finished!\n"), get_name());
    }
}

public class ReportWrapper : Guanako.Reporter {
    private inline void dbg_ref_msg (ReportType type, Vala.SourceReference? source, string message) {
        if (source != null)
            // TRANSLATORS:
            // E.g.: Warning found: myfile.vala: 12(13)-12(17): unused variable `test'
            debug_msg_level (2, _("%s found: %s: %d(%d)-%d(%d): %s\n"),
                             type.to_string(),
                             project.get_relative_path (source.file.filename),
                             source.begin.line,
                             source.end.column,
                             source.end.line,
                             source.end.column,
                             message);
    }

    protected override inline void show_note (Vala.SourceReference? source, string message) {
        dbg_ref_msg (ReportType.NOTE, source, message);
    }

    protected override inline void show_deprecated (Vala.SourceReference? source, string message) {
        dbg_ref_msg (ReportType.DEPRECATED, source, message);
    }

    protected override inline void show_experimental (Vala.SourceReference? source, string message) {
        dbg_ref_msg (ReportType.EXPERIMENTAL, source, message);
     }

    protected override inline void show_warning (Vala.SourceReference? source, string message) {
        dbg_ref_msg (ReportType.WARNING, source, message);
     }

    protected override inline void show_error (Vala.SourceReference? source, string message) {
        dbg_ref_msg (ReportType.ERROR, source, message);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
