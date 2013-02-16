/*
 * src/ui/search.vala
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

/**
 * Search widget
 */
public class UiSearch : UiElement {
    public UiSearch () {
        element_name = "Search";

        tree_view = new TreeView();
        var line_renderer = new CellRendererText();
        line_renderer.yalign = 0;
        tree_view.cursor_changed.connect (on_tree_view_cursor_changed);
        tree_view.insert_column_with_attributes (-1,
                                                 _("Line"),
                                                 line_renderer,
                                                 "text",
                                                 0,
                                                 null);

        tree_view.insert_column_with_attributes (-1,
                                                 "",
                                                 new CellRendererText(),
                                                 "markup",
                                                 1,
                                                 null);


        var box_main = new Box (Orientation.VERTICAL, 0);

        var entry_search = new SearchEntry();
        entry_search.changed.connect(() => {
            if (entry_search.text != "")
                search (entry_search.text);
        });
        box_main.pack_start (entry_search, false, true);

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);
        box_main.pack_start (scrw, true, true);

        build();

        widget = box_main;
    }

    TreeView tree_view;
    public Widget widget;

    Gee.HashMap<string, SearchResult?> map_paths_results;
    struct SearchResult {
        public int line;
        public int col_start;
        public int col_end;
        public string filename;
    }

    void on_tree_view_cursor_changed() {
        TreePath path;
        tree_view.get_cursor (out path, null);
        if (path == null)
            return;
        SearchResult? result = map_paths_results[path.to_string()];
        if (result == null)
            return;
        TextIter titer;
        var bfr = project.get_buffer_by_file (result.filename);
        bfr.get_iter_at_line_offset (out titer,
                                     result.line,
                                     0);
        bfr.select_range (titer, titer);

        var pfile = File.new_for_path (project.project_path);
        var fname = pfile.get_relative_path (File.new_for_path (result.filename));

        source_viewer.focus_src (fname);
        source_viewer.get_sourceview_by_file(fname).scroll_to_iter (titer, 0.42, true, 0, 1.0);
    }

    //Thread<void*> search_thread = null;
    //bool abort_search_thread = false;
    void search(string search) {
        map_paths_results = new Gee.HashMap<string, SearchResult?>();
        /*if (search_thread != null) {
            abort_search_thread = true;
            search_thread.join();
        }
        abort_search_thread = false;
        if (search_thread != null)
            return;*/
        //search_thread = new Thread<void*> (_("Search"), () => {
            var store = new TreeStore (2, typeof (string), typeof (string));
            project.foreach_buffer ((filename, bfr) => {
                TextIter first_iter;
                TextIter end_iter;
                bfr.get_start_iter (out first_iter);
                bfr.get_end_iter (out end_iter);
                bfr.remove_tag_by_name ("search", first_iter, end_iter);

                TextIter? match_start = null;
                TextIter? match_end = null;
                bfr.get_start_iter(out match_end);
                TreeIter? iter_parent = null;
                //while (!abort_search_thread && match_end.forward_search (search, TextSearchFlags.CASE_INSENSITIVE, out match_start, out match_end, null)) {
                while (match_end.forward_search (search, TextSearchFlags.CASE_INSENSITIVE, out match_start, out match_end, null)) {
                    if (iter_parent == null) {
                        store.append (out iter_parent, null);
                        store.set (iter_parent, 0, "", 1, filename, -1);
                    }
                    TreeIter iter_append;
                    store.append (out iter_append, iter_parent);

                    int col_start = match_start.get_line_offset();
                    int col_end = match_end.get_line_offset();
                    bfr.apply_tag_by_name ("search", match_start, match_end);

                    match_start.backward_chars (match_start.get_line_offset());
                    TextIter prepend = match_start;
                    prepend.backward_line();
                    prepend.backward_line();
                    match_end.forward_to_line_end();
                    TextIter append = match_end;
                    append.forward_line();
                    append.forward_line();
                    append.forward_to_line_end();
                    var shown_text = """<tt><span color="#A0A0A0">""" + Markup.escape_text(bfr.get_slice (prepend, match_start, true)) + "</span>"
                                 + Markup.escape_text(bfr.get_slice(match_start, match_end, true)).replace(search, "<b>" + search + "</b>")
                                 + """<span color="#A0A0A0">""" + Markup.escape_text(bfr.get_slice (match_end, append, true)) + "</span></tt>\n";
                    //TODO: Make <b> stuff case insensitive!

                    map_paths_results[store.get_path((TreeIter)iter_append).to_string()] =  SearchResult() { line = match_end.get_line(), filename = filename, col_start = col_start, col_end = col_end };
                    store.set (iter_append, 0, (match_end.get_line() + 1).to_string(), 1, shown_text, -1);
                }
                tree_view.set_model (store);
                /*if (!abort_search_thread)
                    GLib.Idle.add (()=> {
                        var results = map_paths_results.values;
                        project.foreach_buffer ((filename, bfr) => {
                            TextIter first_iter;
                            TextIter end_iter;
                            bfr.get_start_iter (out first_iter);
                            bfr.get_end_iter (out end_iter);
                            bfr.remove_tag_by_name ("search", first_iter, end_iter);
                            foreach (SearchResult result in results)
                                if (result.filename == filename) {
                                    TextIter tag_start, tag_end;
                                    bfr.get_iter_at_line_offset (out tag_start, result.line, result.col_start);
                                    bfr.get_iter_at_line_offset (out tag_end, result.line, result.col_end);
                                    bfr.apply_tag_by_name ("search", tag_start, tag_end);

                                }
                        });

                        tree_view.set_model (store);
                        return false;
                    });*/
            });
            //search_thread = null;
            //return null;
        //});
    }

    public override void build() {
        debug_msg (_("Run %s update!\n"), element_name);
        debug_msg (_("%s update finished!\n"), element_name);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
