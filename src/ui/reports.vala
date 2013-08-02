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
    ListStore store;
    ScrolledWindow scrw;
    Gdk.Pixbuf pixmap_err;
    Gdk.Pixbuf pixmap_warn;
    Gdk.Pixbuf pixmap_depr;
    Gdk.Pixbuf pixmap_exp;
    Gdk.Pixbuf pixmap_note;

    /* Sort order and sort column for showall display mode. */
    //TODO: Make this a configuration option.
    private SortType? sort_order_all = null;
    private int? sort_id_all = null;
    /* Sort order and sort column for file specific display mode. */
    private SortType? sort_order = null;
    private int? sort_id = null;
    /**
     * Synchronize sort order for file specific and display all modes.
     */
    private bool sort_sync = true;

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

            var column_pix = new TreeViewColumn.with_attributes (
                                                     null,
                                                     new CellRendererPixbuf(),
                                                     "pixbuf",
                                                     0,
                                                     null);
            column_pix.sort_column_id = 0;
            tree_view.append_column (column_pix);

            if (value) {
                var column_file = new TreeViewColumn.with_attributes (
                                                    _("File"),
                                                    new CellRendererText(),
                                                    "text",
                                                    1,
                                                    null);
                column_file.sort_column_id = 1;
                tree_view.append_column (column_file);
            }

            var column_loc = new TreeViewColumn.with_attributes (
                                                     _("Location"),
                                                     new CellRendererText(),
                                                     "text",
                                                     (int) value + 1,
                                                     null);
            if (!value)
                column_loc.sort_column_id = 1;
            tree_view.append_column (column_loc);

            var column_errline = new TreeViewColumn.with_attributes (
                                                     _("Error"),
                                                     new CellRendererText(),
                                                     "text",
                                                     (int) value + 2,
                                                     null);
            column_errline.sort_column_id = (int) value + 2;
            tree_view.append_column (column_errline);
            tree_view.can_focus = false;

            var column_err = new TreeViewColumn();
            column_err.visible = false;
            tree_view.append_column (column_err);

            tree_view.row_activated.connect ((path) => {
                TreeIter iter;
                store.get_iter (out iter, path);

                Value err_val;
                store.get_value (iter, (int) value + 3, out err_val);
                var err = err_val as Reporter.Error;
                if (err != null) {
                    source_viewer.jump_to_position (err.source.file.filename,
                                                    err.source.begin.line - 1,
                                                    err.source.begin.column - 1);
                    source_viewer.current_srcview.highlight_line (err.source.begin.line - 1);
                } else
                    bug_msg (_("Could not get %s from %s: %s\n"),
                             "Reporter.Error", "ListStore", "show_all.set");
            });

            scrw.add (tree_view);
            scrw.show_all();

            _showall = value;
            build();

        }
    }

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

        var theme = IconTheme.get_default();
        try {
            //TODO: Does this use fallback icon?
            pixmap_err = theme.load_icon ("dialog-error", IconSize.MENU, IconLookupFlags.GENERIC_FALLBACK);
        } catch (GLib.Error e) {
            errmsg (_("Could not load theme icon: %s\n"), e.message);
        }
        try {
            pixmap_warn = theme.load_icon ("dialog-warning", IconSize.MENU, IconLookupFlags.GENERIC_FALLBACK);
        } catch (GLib.Error e) {
            errmsg (_("Could not load theme icon: %s\n"), e.message);
        }
        try {
            pixmap_depr = theme.load_icon ("dialog-question", IconSize.MENU, IconLookupFlags.GENERIC_FALLBACK);
        } catch (GLib.Error e) {
            errmsg (_("Could not load theme icon: %s\n"), e.message);
        }
        try {
            pixmap_exp = theme.load_icon ("help-about", IconSize.MENU, IconLookupFlags.GENERIC_FALLBACK);
        } catch (GLib.Error e) {
            errmsg (_("Could not load theme icon: %s\n"), e.message);
        }
        try {
            pixmap_note = theme.load_icon ("dialog-information", IconSize.MENU, IconLookupFlags.GENERIC_FALLBACK);
        } catch (GLib.Error e) {
            errmsg (_("Could not load theme icon: %s\n"), e.message);
        }

        project.guanako_update_finished.connect (build);
        source_viewer.current_sourceview_changed.connect (() => {
            if (!this.showall)
                build();
        });

        widget = vbox;
    }

    private int comp_err_filename (TreeModel model, TreeIter a, TreeIter b) {
        Value a_str;
        Value b_str;
        model.get_value (a, 1, out a_str);
        model.get_value (b, 1, out b_str);
        var ret = strcmp ((string) a_str, (string) b_str);
        if (ret != 0)
            return ret;

        Value a_int;
        Value b_int;
        model.get_value (a, 2, out a_int);
        model.get_value (b, 2, out b_int);
        return (int) a_int - (int) b_int;
    }

    private int comp_err_pixbuf (TreeModel model, TreeIter a, TreeIter b) {
        Value a_pix;
        Value b_pix;
        model.get_value (a, 0, out a_pix);
        model.get_value (b, 0, out b_pix);
        var ret = errpix_to_int ((Gdk.Pixbuf) a_pix) - errpix_to_int ((Gdk.Pixbuf) b_pix);
        if (ret != 0)
            return ret;

        ret = comp_err_filename (model, a, b);
        if (tree_view.get_column (0).sort_order == SortType.ASCENDING)
            return ret;
        else
            return (-1)*ret;
    }

    private int errpix_to_int (Gdk.Pixbuf pixbuf) {
        if (pixbuf == pixmap_err)
            return 1;
        else if (pixbuf == pixmap_warn)
            return 2;
        else if (pixbuf == pixmap_depr)
            return 3;
        else if (pixbuf == pixmap_exp)
            return 4;
        else if (pixbuf == pixmap_note)
            return 5;
        bug_msg (_("No valid pixbuf (%s).\n"), "UiReport.errpix_to_int");
        return -1;
    }

    private int comp_err_errors (TreeModel model, TreeIter a, TreeIter b) {
        Value a_str;
        Value b_str;
        model.get_value (a, (int) showall + 2, out a_str);
        model.get_value (b, (int) showall + 2, out b_str);
        var ret = strcmp ((string) a_str, (string) b_str);
        if (ret != 0)
            return ret;

        ret = comp_err_filename (model, a, b);
        if (tree_view.get_column ((int) showall + 2).sort_order == SortType.ASCENDING)
            return ret;
        else
            return (-1)*ret;
    }

    public override void build() {
        if (showall) {
            store = new ListStore (5, typeof (Gdk.Pixbuf),
                                      typeof (string),
                                      typeof (int),
                                      typeof (string),
                                      typeof (Reporter.Error));
            store.set_sort_func (1, comp_err_filename);
            store.set_sort_func (0, comp_err_pixbuf);
            store.set_sort_func ((int) showall + 2, comp_err_errors);

            if (sort_order_all != null && sort_id_all != null)
                store.set_sort_column_id (sort_id_all, sort_order_all);
            else
                store.set_sort_column_id (1, SortType.ASCENDING);
        } else {
            store = new ListStore (4, typeof (Gdk.Pixbuf),
                                      typeof (int),
                                      typeof (string),
                                      typeof (Reporter.Error));
            store.set_sort_func (0, comp_err_pixbuf);
            store.set_sort_func ((int) showall + 2, comp_err_errors);

            if (sort_order != null && sort_id != null)
                store.set_sort_column_id (sort_id, sort_order);
            else
                store.set_sort_column_id (1, SortType.ASCENDING);
        }
        store.sort_column_changed.connect (() => {
            int new_sid;
            SortType new_sorder;
            if (store.get_sort_column_id (out new_sid, out new_sorder)) {
                if (showall) {
                    sort_order_all = new_sorder;
                    sort_id_all = new_sid;
                    if (sort_sync)
                        switch (new_sid) {
                            case 0:
                                sort_order = new_sorder;
                                sort_id = 0;
                                break;
                            case 1: //TODO: Fallthrough to case 2?
                                break;
                            case 2: //NOTE: Currently not reachable.
                                sort_order = new_sorder;
                                sort_id = 1;
                                break;
                            case 3:
                                sort_order = new_sorder;
                                sort_id = 2;
                                break;
                            default:
                                bug_msg (_("No valid column to sort: %d - %s\n"),
                                         new_sid, "UiReport.build (showall)");
                                break;
                        }
                } else {
                    sort_order = new_sorder;
                    sort_id = new_sid;
                    if (sort_sync)
                        switch (new_sid) {
                            case 0:
                                sort_order_all = new_sorder;
                                sort_id_all = 0;
                                break;
                            case 1:
                                break;
                            case 2:
                                sort_order_all = new_sorder;
                                sort_id_all = 3;
                                break;
                            default:
                                bug_msg (_("No valid column to sort: %d - %s\n"),
                                         new_sid, "UiReport.build");
                                break;
                        }
                }
            }
        });
        tree_view.set_model (store);

        if (!showall && !(source_viewer.current_srcfocus in project.files))
            return;

        debug_msg (_("Run %s update!\n"), get_name());

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
                           2, err.source.begin.line,
                           3, err.message,
                           4, err,
                           -1);
            else
                store.set (next,
                           0, pixbuf,
                           1, err.source.begin.line,
                           2, err.message,
                           3, err,
                           -1);
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
