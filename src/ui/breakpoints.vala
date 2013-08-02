/*
 * src/ui/breakpoints.vala
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
 * Setting break points etc.
 */
class UiBreakpoints : UiElement {
    TreeView tree_view;
    Guanako.FrankenStein frankenstein;
    ListStore? store = null;
    MainLoop resume_wait_loop = new MainLoop();

    InfoBar info_bar;

    ToolButton btn_add;
    ToolButton btn_remove;
    ToolButton btn_resume;

    public UiBreakpoints (Guanako.FrankenStein frankenstein) {
        this.frankenstein = frankenstein;
        frankenstein.timer_finished.connect (timer_finished);
        frankenstein.stop_reached.connect (stop_reached);
        frankenstein.received_invalid_id.connect (()=> {
            info_bar.visible = true;
        });
        project_builder.build_started.connect (() => {
            info_bar.visible = false;
        });

        var box_main = new Box (Orientation.VERTICAL, 0);

        tree_view = new TreeView();

        tree_view.insert_column_with_attributes (-1,
                                                 _("Line"),
                                                 new CellRendererText(),
                                                 "text",
                                                 0,
                                                 null);
        tree_view.insert_column_with_attributes (-1,
                                                 _("File"),
                                                 new CellRendererText(),
                                                 "text",
                                                 1,
                                                 null);
        tree_view.insert_column_with_attributes (-1,
                                                 _("Time"),
                                                 new CellRendererText(),
                                                 "text",
                                                 2,
                                                 null);

        build();

        tree_view.can_focus = false;
        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);
        box_main.pack_start (scrw, true, true);

        var toolbar = new Toolbar();
        toolbar.icon_size = 1;

        btn_add = new ToolButton (null, null);
        btn_add.sensitive = false;
        btn_add.icon_name = "list-add-symbolic";
        btn_add.clicked.connect (on_btn_add_clicked);
        toolbar.add (btn_add);

        btn_remove = new ToolButton (null, null);
        btn_remove.sensitive = false;
        btn_remove.icon_name = "list-remove-symbolic";
        btn_remove.clicked.connect (on_btn_remove_clicked);
        toolbar.add (btn_remove);

        btn_resume = new ToolButton (null, null);
        btn_resume.sensitive = false;
        btn_resume.icon_name = "media-playback-start";
        btn_resume.clicked.connect (on_btn_resume_clicked);
        toolbar.add (btn_resume);

        box_main.pack_start (toolbar, false, true);

        info_bar = new InfoBar();
        var content_area = (Container)info_bar.get_content_area();
        var info_box = new Box(Orientation.HORIZONTAL, 5);
        info_box.pack_start (new Image.from_icon_name ("dialog-error", IconSize.LARGE_TOOLBAR), false, true);
        info_box.pack_start (new Label (_("Received invalid ID. Try to rebuild.")), true, true);
        content_area.add (info_box);
        content_area.show_all();
        info_bar.no_show_all = true;
        box_main.pack_start (info_bar, false, true);

        mode_to_show (IdeModes.DEBUG);

        source_viewer.current_sourceview_changed.connect (() => {
            /* Don't enable button on non-source files. */
            if (source_viewer.current_srcfocus != null &&
                        project.guanako_project.get_source_file_by_name (
                                    source_viewer.current_srcfocus) != null)
                btn_add.sensitive = true;
            else
                btn_add.sensitive = false;
        });

        project.guanako_update_finished.connect(update_source_marks);

        tree_view.cursor_changed.connect (() => {
            TreePath path;
            tree_view.get_cursor (out path, null);
            if (path == null)
                btn_remove.sensitive = false;
            else
                btn_remove.sensitive = true;
        });

        widget = box_main;
    }

    void timer_finished (FrankenStein.FrankenTimer timer, int timer_id, double time) {
        widget_main.focus_dock_item (this.dock_item);

        var pth = new TreePath.from_indices (timer_id);
        TreeIter iter;
        store.get_iter (out iter, pth);
        store.set (iter, 2, time.to_string(), -1);
        tree_view.set_cursor (pth, null, false);
        source_viewer.focus_src (timer.file.filename);
        var view = source_viewer.get_sourceview_by_file (timer.file.filename);
        view.highlight_line (timer.start_line - 1);
    }

    void stop_reached (FrankenStein.FrankenStop stop, int stop_id) {
        widget_main.focus_dock_item (this.dock_item);

        var pth = new TreePath.from_indices (frankenstein.frankentimers.size + stop_id);
        tree_view.set_cursor (pth, null, false);
        btn_resume.sensitive = true;
        source_viewer.focus_src (stop.file.filename);
        var view = source_viewer.get_sourceview_by_file (stop.file.filename);
        view.highlight_line (stop.line - 1);
        resume_wait_loop.run();
    }

    void on_btn_resume_clicked() {
        btn_resume.sensitive = false;
        resume_wait_loop.quit();
    }

    void on_btn_add_clicked() {
        TextIter iter_start;
        TextIter iter_end;
        /* Make sure current_srcfocus != null. */
        var focus_file = project.guanako_project.get_source_file_by_name (
                                                        source_viewer.current_srcfocus);
        if (!source_viewer.current_srcbuffer.get_selection_bounds (out iter_start, out iter_end)) {
            var mark_insert = source_viewer.current_srcbuffer.get_insert();
            source_viewer.current_srcbuffer.get_iter_at_mark (out iter_start, mark_insert);
            iter_end = iter_start;
        }
        if (iter_start.get_line() == iter_end.get_line()){
            var new_stop = new FrankenStein.FrankenStop(focus_file, iter_start.get_line() + 1, true);
            if (stop_exists (new_stop))
                return;
            frankenstein.frankenstops.add (new_stop);
            btn_remove.sensitive = true;
        } else {
            var new_timer = new FrankenStein.FrankenTimer(focus_file, iter_start.get_line() + 1, iter_end.get_line() + 1, true);
            if (timer_exists (new_timer))
                return;
            frankenstein.frankentimers.add (new_timer);
            btn_remove.sensitive = true;
        }
        project_builder.request_compile();
        build();
    }

    bool stop_exists (FrankenStein.FrankenStop stop) {
        foreach (FrankenStein.FrankenStop s in frankenstein.frankenstops)
            if (s != stop && s.line == stop.line && s.file == stop.file)
                return true;
        return false;
    }

    bool timer_exists (FrankenStein.FrankenTimer timer) {
        foreach (FrankenStein.FrankenTimer t in frankenstein.frankentimers)
            if (t != timer && t.start_line == timer.start_line && t.end_line == timer.end_line && t.file == timer.file)
                return true;
        return false;
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

        if (frankenstein.frankentimers.size == 0 && frankenstein.frankenstops.size == 0)
            btn_remove.sensitive = false;

        project_builder.request_compile();
        build();
    }

    public override void build() {
        debug_msg (_("Run %s update!\n"), get_name());
        
        TreePath old_cursor;
        tree_view.get_cursor (out old_cursor, null);

        store = new ListStore (3, typeof (string), typeof (string), typeof (string));
        tree_view.set_model (store);


        foreach (Guanako.FrankenStein.FrankenTimer timer in frankenstein.frankentimers) {
            TreeIter next;
            store.append (out next);
            store.set (next,
                       0,
                       timer.start_line.to_string() + " - " + timer.end_line.to_string(),
                       1,
                       project.get_relative_path (timer.file.filename),
                       -1);
        }

        foreach (Guanako.FrankenStein.FrankenStop stop in frankenstein.frankenstops) {
            TreeIter next;
            store.append (out next);
            store.set (next,
                       0,
                       stop.line.to_string(),
                       1,
                       project.get_relative_path (stop.file.filename),
                       -1);

        }

        if (old_cursor != null)
            tree_view.set_cursor (old_cursor, null, false);

        /* Clear existing marks */
        project.foreach_buffer((s, bfr)=>{
            TextIter first_iter;
            TextIter end_iter;
            bfr.get_start_iter (out first_iter);
            bfr.get_end_iter (out end_iter);
            bfr.remove_source_marks(first_iter, end_iter, "timer");
            bfr.remove_source_marks(first_iter, end_iter, "stop");
        });
        map_timer_starts = new Gee.HashMap<Guanako.FrankenStein.FrankenTimer?, SourceMark>();
        map_timer_ends = new Gee.HashMap<Guanako.FrankenStein.FrankenTimer?, SourceMark>();
        map_breakpoints = new Gee.HashMap<Guanako.FrankenStein.FrankenStop?, SourceMark>();

        /* Add marks */
        foreach (FrankenStein.FrankenTimer timer in frankenstein.frankentimers) {
            var bfr = project.get_buffer_by_file (timer.file.filename);
            TextIter iter_start;
            TextIter iter_end;
            bfr.get_iter_at_line (out iter_start, timer.start_line - 1);
            bfr.get_iter_at_line (out iter_end, timer.end_line - 1);

            map_timer_starts[timer] = bfr.create_source_mark (null, "timer", iter_start);
            map_timer_ends[timer] = bfr.create_source_mark (null, "timer", iter_end);
        }
        foreach (FrankenStein.FrankenStop stop in frankenstein.frankenstops) {
            var bfr = project.get_buffer_by_file (stop.file.filename);
            TextIter iter;
            bfr.get_iter_at_line (out iter, stop.line - 1);

            map_breakpoints[stop] = bfr.create_source_mark (null, "stop", iter);
        }

        debug_msg (_("%s update finished!\n"), get_name());
    }

    Gee.HashMap<FrankenStein.FrankenTimer?, SourceMark> map_timer_starts;
    Gee.HashMap<FrankenStein.FrankenTimer?, SourceMark> map_timer_ends;
    Gee.HashMap<FrankenStein.FrankenStop?, SourceMark> map_breakpoints;
    void update_source_marks() {
        bool need_update = false;

        TextIter? iter = null;
        map_timer_starts.map_iterator().foreach ((timer, mark) => {
            var bfr = project.get_buffer_by_file (timer.file.filename);
            bfr.get_iter_at_mark (out iter, mark);
            if (iter == null)
                return true;
            if (timer.start_line != iter.get_line() + 1) {
                timer.start_line = iter.get_line() + 1;
                if (timer_exists (timer))
                    frankenstein.frankentimers.remove (timer);
                need_update = true;
            }
            return true;
        });

        map_timer_ends.map_iterator().foreach ((timer, mark) => {
            var bfr = project.get_buffer_by_file (timer.file.filename);
            bfr.get_iter_at_mark (out iter, mark);
            if (iter == null)
                return true;
            if (timer.end_line != iter.get_line() + 1) {
                timer.end_line = iter.get_line() + 1;
                if (timer_exists (timer))
                    frankenstein.frankentimers.remove (timer);
                need_update = true;
            }
            return true;
        });

        map_breakpoints.map_iterator().foreach ((stop, mark) => {
            var bfr = project.get_buffer_by_file (stop.file.filename);
            bfr.get_iter_at_mark (out iter, mark);
            if (iter == null)
                return true;
            if (stop.line != iter.get_line() + 1) {
                stop.line = iter.get_line() + 1;
                if (stop_exists (stop))
                    frankenstein.frankenstops.remove (stop);
                need_update = true;
            }
            return true;
        });

        if (need_update) {
            project_builder.request_compile();
            build();
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
