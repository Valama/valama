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
public class UiSearch : UiElementExt {
    TreeView tree_view;
    ToggleToolButton btn_all_files;
#if GTK_3_6
    SearchEntry entry_search;
#else
    Entry entry_search;
#endif

    public UiSearch () {
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

        var toolbar_title = new Toolbar ();
        toolbar_title.get_style_context().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
        var ti_title = new ToolItem();
        ti_title.add (new Label (_("Search")));
        toolbar_title.add(ti_title);

        var separator_stretch = new SeparatorToolItem();
        separator_stretch.set_expand (true);
        separator_stretch.draw = false;
        toolbar_title.add (separator_stretch);

        btn_all_files = new ToggleToolButton ();
        btn_all_files.clicked.connect (() => {
            search (entry_search.text);
        });
        btn_all_files.label = _("All files");
        btn_all_files.is_important = true;
        toolbar_title.add (btn_all_files);
        box_main.pack_start (toolbar_title, false, true);

#if GTK_3_6
        entry_search = new SearchEntry();
#else
        entry_search = new Entry();
#endif

        entry_search.changed.connect(() => {
            search (entry_search.text);
        });
        box_main.pack_start (entry_search, false, true);

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);
        box_main.pack_start (scrw, true, true);

        build();

        source_viewer.current_sourceview_changed.connect (() => {
            if (!btn_all_files.active)
                search (entry_search.text);
        });

        widget = box_main;
    }

    protected override void on_element_show() {
        if (source_viewer.current_srcbuffer != null) {
            TextIter sel_start, sel_end;
            source_viewer.current_srcbuffer.get_selection_bounds (out sel_start, out sel_end);
            entry_search.text = source_viewer.current_srcbuffer.get_text (sel_start, sel_end, true);
        }
        focus_entry_search();
    }

    protected override void on_element_hide() {}

    public void focus_entry_search() {
        entry_search.grab_focus();
        entry_search.select_region (0, entry_search.text.length);
    }

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
        var bfr = vproject.get_buffer_by_file (result.filename);
        bfr.get_iter_at_line_offset (out titer,
                                     result.line,
                                     0);
        bfr.select_range (titer, titer);
        source_viewer.focus_src (result.filename);
        source_viewer.get_sourceview_by_file (result.filename).scroll_to_iter (
                                                                titer, 0.42, true, 0, 1.0);
    }

    void clear_search_tag() {
        vproject.foreach_buffer ((filename, bfr) => {
            TextIter first_iter;
            TextIter end_iter;
            bfr.get_start_iter (out first_iter);
            bfr.get_end_iter (out end_iter);
            bfr.remove_tag_by_name ("search", first_iter, end_iter);
        });
    }


    void search(string search) {
        clear_search_tag();
        if (search == "")
            return;
        map_paths_results = new Gee.HashMap<string, SearchResult?>();

        var store = new TreeStore (2, typeof (string), typeof (string));
        if (!btn_all_files.active)
            search_buffer (search,
                           source_viewer.current_srcbuffer,
                           store,
                           source_viewer.current_srcfocus);
        else
            vproject.foreach_buffer ((filename, bfr) => {
                search_buffer (search, bfr, store, filename);
            });
        tree_view.set_model (store);
    }

    void search_buffer(string search, SourceBuffer bfr, TreeStore store, string filename) {
        TextIter first_iter;
        TextIter end_iter;
        bfr.get_start_iter (out first_iter);
        bfr.get_end_iter (out end_iter);
        bfr.remove_tag_by_name ("search", first_iter, end_iter);

        TextIter? match_start = null;
        TextIter? match_end = null;
        bfr.get_start_iter(out match_end);
        TreeIter? iter_parent = null;

        while (match_end.forward_search (search,
                                         TextSearchFlags.CASE_INSENSITIVE,
                                         out match_start,
                                         out match_end,
                                         null)) {
            if (iter_parent == null && btn_all_files.active) {
                store.append (out iter_parent, null);
                store.set (iter_parent, 0, "", 1, vproject.get_relative_path (filename), -1);
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
            append.forward_to_line_end();
            var shown_text = """<tt><span color="#A0A0A0">"""
                        + Markup.escape_text (bfr.get_slice (prepend, match_start, true))
                        + "</span>"
                        + Markup.escape_text (bfr.get_slice (
                                        match_start, match_end, true)).replace (
                                                                search, "<b>" + search + "</b>")
                        + """<span color="#A0A0A0">"""
                        + Markup.escape_text (bfr.get_slice (match_end, append, true))
                        + "</span></tt>\n";
            shown_text = shown_text.strip();
            //TODO: Make <b> stuff case insensitive!
            map_paths_results[store.get_path ((TreeIter)iter_append).to_string()]
                                        = SearchResult() { line = match_end.get_line(),
                                                           filename = filename,
                                                           col_start = col_start,
                                                           col_end = col_end };
            store.set (iter_append, 0, (match_end.get_line() + 1).to_string(), 1, shown_text, -1);
        }
    }

    public override void build() {
        debug_msg (_("Run %s update!\n"), get_name());
        debug_msg (_("%s update finished!\n"), get_name());
    }
}

// vim: set ai ts=4 sts=4 et sw=4
