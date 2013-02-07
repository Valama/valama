/*
 * src/ui_reports.vala
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

/**
 * Report build status and code warnings/errors.
 */
class UiReport : UiElement {
    ReportWrapper report;
    TreeView tree_view;
    public Widget widget;

    public UiReport (ReportWrapper report) {
        this.report = report;

        element_name = "UiReport";

        tree_view = new TreeView();
        tree_view.insert_column_with_attributes (-1, _("Location"), new CellRendererText(), "text", 0, null);
        tree_view.insert_column_with_attributes (-1, _("Error"), new CellRendererText(), "text", 1, null);

        build();

        tree_view.row_activated.connect ((path) => {
            int index = path.get_indices()[0];
            if (report.errors_list.size > index)
                error_selected (report.errors_list[index]);
            else
                error_selected (report.warnings_list[index - report.errors_list.size]);
        });
        tree_view.can_focus = false;

        widget = tree_view;
    }

    public signal void error_selected (ReportWrapper.Error error);

    public override void build() {
#if DEBUG
        stderr.printf (_("Run %s update!\n"), element_name);
#endif
        var store = new ListStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        foreach (ReportWrapper.Error err in report.errors_list) {
            TreeIter next;
            store.append (out next);
            store.set (next, 0, err.source.begin.line.to_string(), 1, err.message, -1);
        }
        foreach (ReportWrapper.Error err in report.warnings_list) {
            TreeIter next;
            store.append (out next);
            store.set (next, 0, err.source.begin.line.to_string(), 1, err.message, -1);
        }

        project.foreach_buffer((s, bfr)=>{
            TextIter first_iter;
            TextIter end_iter;
            bfr.get_start_iter (out first_iter);
            bfr.get_end_iter (out end_iter);
            bfr.remove_tag_by_name ("error_bg", first_iter, end_iter);
            bfr.remove_tag_by_name ("warning_bg", first_iter, end_iter);
        });
        foreach (ReportWrapper.Error err in report.errors_list) {
            var bfr = project.get_buffer_by_file (err.source.file.filename);
            if (bfr == null)
                continue;

            TextIter iter_start;
            TextIter iter_end;
            bfr.get_iter_at_line (out iter_start, err.source.begin.line - 1);
            bfr.get_iter_at_line (out iter_end, err.source.end.line - 1);
            iter_start.forward_chars (err.source.begin.column - 1);
            iter_end.forward_chars (err.source.end.column);
            bfr.apply_tag_by_name ("error_bg", iter_start, iter_end);
        }
        foreach (ReportWrapper.Error warn in report.warnings_list) {
            var bfr = project.get_buffer_by_file (warn.source.file.filename);
            if (bfr == null)
                continue;

            TextIter iter_start;
            TextIter iter_end;
            bfr.get_iter_at_line (out iter_start, warn.source.begin.line - 1);
            bfr.get_iter_at_line (out iter_end, warn.source.end.line - 1);
            iter_start.forward_chars (warn.source.begin.column - 1);
            iter_end.forward_chars (warn.source.end.column);
            bfr.apply_tag_by_name ("warning_bg", iter_start, iter_end);
        }

        /*while (first_iter.forward_search ("guanako", TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY, out start_match, out end_match, null)){
            bfr.apply_tag_by_name (
        }*/

#if DEBUG
        stdout.printf (_("Errors: %i, Warnings: %i\n"), report.errors_list.size, report.warnings_list.size);
#endif
#if DEBUG
        stderr.printf (_("%s update finished!\n"), element_name);
#endif
    }
}

public class ReportWrapper : Vala.Report {
    public Vala.List<Error?> errors_list = new Vala.ArrayList<Error?>();
    public Vala.List<Error?> warnings_list = new Vala.ArrayList<Error?>();
    bool general_error = false;

    public struct Error {
        public Vala.SourceReference source;
        public string message;
    }

    public void clear() {
        errors_list = new Vala.ArrayList<Error?>();
        warnings_list = new Vala.ArrayList<Error?>();
    }

    public override void warn (Vala.SourceReference? source, string message) {
#if DEBUG
        stdout.printf (_("Warning found: %s: %d(%d)-%d(%d): %s\n"),
                                               source.file.filename,
                                               source.begin.line,
                                               source.end.column,
                                               source.end.line,
                                               source.end.column,
                                               message);
#endif
        if (source == null)
            return;
        //lock (errors_list) {
        warnings_list.add(Error() {source = source, message = message});
        //}
     }

     public override void err (Vala.SourceReference? source, string message) {
#if DEBUG
        stdout.printf (_("Error found: %s: %d(%d)-%d(%d): %s\n"),
                                               source.file.filename,
                                               source.begin.line,
                                               source.begin.column,
                                               source.end.line,
                                               source.end.column,
                                               message);
#endif

         if (source == null) {
             general_error = true;
             return;
         }
         //lock (errors_list) {
         errors_list.add (Error() {source = source, message = message});
         //}
    }
}

// vim: set ai ts=4 sts=4 et sw=4
