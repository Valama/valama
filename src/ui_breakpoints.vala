/*
 * src/ui_breakpoints.vala
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

using GLib;
using Gtk;
using Guanako;

/**
 * Setting break points etc
 */
class UiBreakpoints : UiElement {
    TreeView tree_view;
    public Widget widget;
    Guanako.FrankenStein frankenstein;
    ToolButton btn_resume;

    public UiBreakpoints (Guanako.FrankenStein frankenstein) {
        this.frankenstein = frankenstein;
        frankenstein.timer_finished.connect (timer_finished);
        frankenstein.stop_reached.connect (stop_reached);

        element_name = "UiBreakpoints";

        var box_main = new Box (Orientation.VERTICAL, 0);

        tree_view = new TreeView();
        tree_view.insert_column_with_attributes (-1, _("Line"), new CellRendererText(), "text", 0, null);
        tree_view.insert_column_with_attributes (-1, _("File"), new CellRendererText(), "text", 1, null);
        tree_view.insert_column_with_attributes (-1, _("Time"), new CellRendererText(), "text", 2, null);

        build();

        /*tree_view.cursor_changed.connect (() => {

        });*/
        tree_view.row_activated.connect ((path) => {
            /*int index = path.get_indices()[0];
            if (report.errors_list.size > index)
                error_selected (report.errors_list[index]);
            else
                error_selected (report.warnings_list[index - report.errors_list.size]);*/
        });
        tree_view.can_focus = false;
        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);
        box_main.pack_start (scrw, true, true);

        var toolbar = new Toolbar();
        toolbar.icon_size = 1;
        var btn_add = new ToolButton (null, null);
        btn_add.icon_name = "list-add-symbolic";
        btn_add.clicked.connect (on_btn_add_clicked);
        toolbar.add (btn_add);
        var btn_remove = new ToolButton (null, null);
        btn_remove.icon_name = "list-remove-symbolic";
        btn_remove.clicked.connect (on_btn_remove_clicked);
        toolbar.add (btn_remove);
        btn_resume = new ToolButton (null, null);
        btn_resume.stock_id = Stock.MEDIA_PLAY;
        btn_resume.clicked.connect (on_btn_resume_clicked);
        toolbar.add (btn_resume);
        btn_resume.sensitive = false;
        box_main.pack_start (toolbar, false, true);

        window_main.IDEmode_changed.connect(()=>{
            var active = window_main.IDEmode == IDEmodes.DEBUG;
            box_main.sensitive = active;
        });

        widget = box_main;
    }
    MainLoop resume_wait_loop = new MainLoop();
    void timer_finished (FrankenStein.FrankenTimer timer, int timer_id, double time) {
        var pth = new TreePath.from_indices (timer_id);
        TreeIter iter;
        store.get_iter (out iter, pth);
        store.set (iter, 2, time.to_string(), -1);
    }
    void stop_reached (FrankenStein.FrankenStop stop, int stop_id) {
        btn_resume.sensitive = true;
        resume_wait_loop.run();
    }
    void on_btn_resume_clicked() {
        btn_resume.sensitive = false;
        resume_wait_loop.quit();
    }
    void on_btn_add_clicked() {
        TextIter iter_start;
        TextIter iter_end;
        var focus_file = project.guanako_project.get_source_file_by_name (Path.build_path (Path.DIR_SEPARATOR_S, project.project_path, window_main.current_srcfocus));
        if (!window_main.current_srcbuffer.get_selection_bounds (out iter_start, out iter_end)) {
            var mark_insert = window_main.current_srcbuffer.get_insert();
            TextIter iter;
            window_main.current_srcbuffer.get_iter_at_mark (out iter, mark_insert);
            var new_stop = FrankenStein.FrankenStop() { file = focus_file, line = iter.get_line() + 1 };
            frankenstein.frankenstops.add (new_stop);
        } else {
            var new_timer = FrankenStein.FrankenTimer() { file = focus_file, start_line = iter_start.get_line() + 1, end_line = iter_end.get_line() + 1 };
            frankenstein.frankentimers.add (new_timer);
        }
        build();
    }
    void on_btn_remove_clicked() {
        TreePath path;
        tree_view.get_cursor (out path, null);
        if (path == null)
            return;
        int index = path.get_indices()[0];
        if (index < frankenstein.frankentimers.size)
            frankenstein.frankentimers.remove_at (index);
        else
            frankenstein.frankenstops.remove_at (index - frankenstein.frankentimers.size);

        build();
    }

    ListStore store = null;
    public override void build() {
        debug_msg (_("Run %s update!\n"), element_name);
        store = new ListStore (3, typeof (string), typeof (string), typeof (string));
        tree_view.set_model (store);

        project.foreach_buffer((s, bfr)=>{
            TextIter first_iter;
            TextIter end_iter;
            bfr.get_start_iter (out first_iter);
            bfr.get_end_iter (out end_iter);
            bfr.remove_source_marks(first_iter, end_iter, "timer");
            bfr.remove_source_marks(first_iter, end_iter, "stop");
        });

        foreach (Guanako.FrankenStein.FrankenTimer timer in frankenstein.frankentimers) {
            TreeIter next;
            store.append (out next);
            store.set (next, 0, timer.start_line.to_string() + " - " + timer.end_line.to_string(), 1, timer.file.filename, -1);

            var bfr = project.get_buffer_by_file (timer.file.filename);
            TextIter iter_start;
            TextIter iter_end;
            bfr.get_iter_at_line (out iter_start, timer.start_line - 1);
            bfr.get_iter_at_line (out iter_end, timer.end_line - 1);
            bfr.create_source_mark (null, "timer", iter_start);
            bfr.create_source_mark (null, "timer", iter_end);
        }
        foreach (Guanako.FrankenStein.FrankenStop stop in frankenstein.frankenstops) {
            TreeIter next;
            store.append (out next);
            store.set (next, 0, stop.line.to_string(), 1, stop.file.filename, -1);

            var bfr = project.get_buffer_by_file (stop.file.filename);
            TextIter iter;
            bfr.get_iter_at_line (out iter, stop.line - 1);
            bfr.create_source_mark (null, "stop", iter);
        }

        debug_msg (_("%s update finished!\n"), element_name);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
