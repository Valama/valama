/*
 * src/ui_source_viewer.vala
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
using Gdl;
using Gee;

/**
 * Report build status and code warnings/errors.
 */
class UiSourceViewer : UiElement {
    /**
     * Source code dock.
     */
    private Dock srcdock;
    /**
     * Layout of source code dock {@link srcdock}.
     */
    private DockLayout srclayout;
    /**
     * List of all {@link Gdl.DockItem} objects in source dock {@link srcdock}.
     */
    private ArrayList<DockItem> srcitems = new ArrayList<DockItem>();

    /**
     * Share map of language mapping across all source elements.
     */
    private TreeMap<string, Pair<string, int>> langmap;
    /**
     * Share {@link Gtk.SourceLanguageManager} across all source elements.
     */
    private SourceLanguageManager langman;
    /**
     * Fallback language string.
     */
    private const string lang_fallback = N_("Plain text");

    private string? _current_srcfocus = null;
    /**
     * Relative path to current selected {@link SourceBuffer}.
     */
    public string current_srcfocus {
        get {
            return _current_srcfocus;
        }
        private set {
            if (this._current_srcfocus != value) {
                // TRANSLATORS: Change focus of source view to new file.
                debug_msg (_("Change current focus: %s\n"), value);

                this._current_srcfocus = value;
                this.current_srcid = get_sourceview_id (value);
                if (0 <= this.current_srcid < this.srcitems.size) {
                    this.current_srcview = get_sourceview (this.srcitems[this.current_srcid]);
                    this.current_srcbuffer = (SourceBuffer) this.current_srcview.buffer;
                } else
                    warning_msg (_("Could not select current source view: %s\n" +
                                 "Expected behavior may change.\n"), this._current_srcfocus);
                current_sourceview_changed();
            }
        }
    }
    /**
     * Id of current {@link Gtk.SourceView} in {@link srcitems}.
     */
    private int current_srcid { get; private set; default = -1; }
    /**
     * Currently selected {@link Gtk.SourceView}.
     */
    public SuperSourceView? current_srcview { get; private set; default = null; }
    /**
     * List of currently in used annotations.
     */
    private ArrayList<SuperSourceView.LineAnnotation> annotations;
    /**
     * Currently selected {@link SourceBuffer}.
     */
    public SourceBuffer? current_srcbuffer { get; private set; default = null; }
    /**
     * Gets emitted when another {@link Gtk.SourceView} is selected
     */
    public signal void current_sourceview_changed();

    /**
     * Create source viewer object and initialize {@link Gdl.Dock}.
     */
    public UiSourceViewer() {
        locking = false;

        var vbox = new Box (Orientation.VERTICAL, 0);

        srcdock = new Dock();
        vbox.pack_start (this.srcdock, true, true);
        /* Mapping warnings may show up. See #697700 */
        this.srcdock.master.switcher_style = SwitcherStyle.TABS;
#if GDL_3_9_91
        this.srcdock.master.tab_pos = PositionType.TOP;
        this.srcdock.master.tab_reorderable = true;
#endif
        this.srclayout = new DockLayout (this.srcdock);

        langmap = new TreeMap<string, Pair<string, int>>();
        int num = 0;
        langmap[lang_fallback] = new Pair<string, int> (lang_fallback, num);

        langman = new SourceLanguageManager();
        foreach (var lang_id in langman.get_language_ids()) {
            var language = langman.get_language (lang_id).name;
            langmap[language] = new Pair<string, int> (lang_id, ++num);
        }

        annotations = new ArrayList<SuperSourceView.LineAnnotation>();

        widget = vbox;
    }

    /**
     * Initialize application signals.
     */
    public void init() {
        source_viewer.buffer_close.connect (project.close_buffer);
        source_viewer.current_sourceview_changed.connect (() => {
            var srcbuf = source_viewer.current_srcbuffer;
            project.undo_changed (srcbuf.can_undo);
            project.redo_changed (srcbuf.can_redo);
            if (!is_new_document (source_viewer.current_srcfocus))
                project.buffer_changed (project.buffer_is_dirty (
                                                source_viewer.current_srcfocus));
            else
                project.buffer_changed (true);
        });

        project.guanako_update_finished.connect (() => {
            project.foreach_buffer ((s, bfr) => {
                TextIter first_iter;
                TextIter end_iter;
                bfr.get_start_iter (out first_iter);
                bfr.get_end_iter (out end_iter);
                bfr.remove_tag_by_name ("error_bg", first_iter, end_iter);
                bfr.remove_tag_by_name ("warning_bg", first_iter, end_iter);
            });

            foreach (var annotation in annotations)
                annotation.finished = true;
            annotations = new ArrayList<SuperSourceView.LineAnnotation>();

            foreach (var err in project.get_errorlist()) {
                var bfr = project.get_buffer_by_file (err.source.file.filename);
                if (bfr != null)
                    apply_annotation (get_sourceview_by_file (err.source.file.filename, false),
                                      bfr,
                                      err);
            }
        });
    }

    private void apply_annotation (SuperSourceView view, SourceBuffer bfr, Guanako.Reporter.Error err) {
        TextIter? iter_start = null;
        TextIter? iter_end = null;

        // We have broken message positions in some cases ...
        get_safe_iters_from_source_ref (bfr, err.source, ref iter_start, ref iter_end);

        // end == begin -> we want to make sure that the error is visible
        // There is also a case where end > begin but I can't remember
        // how to trigger it. I think it has something to do with main blocks.
        if (iter_end.compare (iter_start) <= 0) {
            iter_end = iter_start;
            bool tmp = iter_end.forward_char();
            if (tmp == false)
                iter_start.backward_char();

            // We have to make sure that there is at least one
            // visible character between start and end
            // Example: "public class Foo {"
            // => The missing-}-error is invisible
            if (!contains_invisible_char (iter_start, iter_end))
                extend_to_invisible_char (ref iter_start, ref iter_end);
        }

        var annotation_line = err.source.begin.line - 1;
        int offset = 1;
        foreach (var annotation in annotations)
            if (annotation.line == annotation_line)
                offset++;

        switch (err.type) {
            case Guanako.ReportType.ERROR:
                bfr.apply_tag_by_name ("error_bg", iter_start, iter_end);
                annotations.add (view.annotate (annotation_line, err.message, 1.0, 0.0, 0.0, false, offset));
                break;
            case Guanako.ReportType.WARNING:
                bfr.apply_tag_by_name ("warning_bg", iter_start, iter_end);
                annotations.add (view.annotate (annotation_line, err.message, 1.0, 1.0, 0.0, false, offset));
                break;
            case Guanako.ReportType.DEPRECATED:
                annotations.add (view.annotate (annotation_line, err.message, 0.0, 0.0, 1.0, false, offset));
                break;
            case Guanako.ReportType.EXPERIMENTAL:
                annotations.add (view.annotate (annotation_line, err.message, 1.0, 1.0, 0.0, false, offset));
                break;
            case Guanako.ReportType.NOTE:
                break;
            default:
                bug_msg (_("Unknown ReportType: %s\n"), err.type.to_string());
                break;
        }
    }

    private inline bool contains_invisible_char (TextIter start, TextIter end) {
        return start.forward_find_char ((c) => { return c.iscntrl() == false; }, end);
    }

    private inline void extend_to_invisible_char (ref TextIter iter_start, ref TextIter iter_end) {
        TextIter iter = iter_end;
        do {
                if (iter.get_char().iscntrl() == false) {
                        iter_start = iter;
                        iter_end = iter;
                        iter_end.forward_char();
                        return;
                }
        } while (iter.forward_char());

        iter = iter_start;
        do {
                if (iter.get_char().iscntrl() == false) {
                        iter_start = iter;
                        iter_end = iter;
                        iter_end.forward_char();
                        return;
                }
        } while (iter.backward_char());
    }

    /**
     * Focus source view {@link Gdl.DockItem} in {@link Gdl.Dock} and select
     * recursively all {@link Gdl.DockNotebook} tabs.
     *
     * @param filename Absolute name of file to focus.
     */
    public void focus_src (string filename) {
        foreach (var srcitem in srcitems) {
            if (project.get_absolute_path (srcitem.long_name) == filename) {
                widget_main.focus_dock_item (srcitem);
                Idle.add (() => {
                    get_sourceview (srcitem).grab_focus();
                    return false;
                });
                return;
            }
        }
        // TRANSLATORS: Could not change source view focus to new file.
        warning_msg (_("Could not change focus to: %s\n"), filename);
    }

    /**
     * Connect to this signal to interrupt hiding (closing) of
     * {@link Gdl.DockItem} with {@link Gtk.SourceView}.
     *
     * @param view {@link Gtk.SourceView} to close.
     * @param filename Name of file to close.
     * @return Return `false` to interrupt or return `true` to proceed.
     */
    public signal bool buffer_close (SourceView view, string? filename);

    /**
     * Close {@link Gdl.DockItem} with {@link Gtk.SourceView} by
     * filename.
     *
     * @param filename Absolute name of source file to close.
     */
    public void close_srcitem (string filename) {
        DockItem? item = null;
        if (!is_new_document (filename)) {
            foreach (var srcitem in srcitems)
                if (project.get_absolute_path (srcitem.long_name) == filename) {
                    item = srcitem;
                    break;
                }
        } else {
            foreach (var srcitem in srcitems)
                if (srcitem.long_name == filename) {
                    item = srcitem;
                    break;
                }
        }
        if (item != null) {
            close_srcitem_pr (item, filename);
            project.close_viewbuffer (filename);
        } else
            warning_msg (_("Could not close view: %s\n"), filename);
    }

    private inline void close_srcitem_pr (DockItem item, string filename) {
        debug_msg (_("Close view and buffer: %s\n"), filename);
        srcitems.remove (item);
        item.unbind();
        if (srcitems.size == 1)
            srcitems[0].show_item();
        var fname = srcitems[srcitems.size - 1].long_name;
        if (is_new_document (fname))
            current_srcfocus = fname;
        else
            current_srcfocus = project.get_absolute_path (fname);
    }

    /**
     * Add new source view item to source dock {@link srcdock}.
     *
     * @param view {@link Gtk.SourceView} object to add.
     * @param filepath Name of file (used to identify item).
     */
    public void add_srcitem (SuperSourceView view, string filepath = "") {
        string displayname, filename = filepath;
        if (filename == "")
            displayname = filename = _("New document");
        else {
            filename = project.get_absolute_path (filename);
            displayname = project.get_relative_path (filename);
        }

        var vbox = new Box (Orientation.VERTICAL, 0);

        var src_view = new ScrolledWindow (null, null);
        vbox.pack_start (src_view, true, true);
        src_view.add (view);

        var srcbuf = (SourceBuffer) view.buffer;
        var attr = new SourceMarkAttributes();
        attr.icon_name = "media-seek-forward";
        view.set_mark_attributes ("timer", attr, 0);
        var attr2 = new SourceMarkAttributes();
        attr2.icon_name = "media-seek-stop";
        view.set_mark_attributes ("stop", attr2, 0);
        view.show_line_marks = true;

        TextTag tag = srcbuf.create_tag ("error_bg", null);
        tag.underline = Pango.Underline.ERROR;
        tag = srcbuf.create_tag ("warning_bg", null);
        tag.background_rgba = Gdk.RGBA() { red = 1.0, green = 1.0, blue = 0.8, alpha = 1.0 };
        tag = srcbuf.create_tag ("search", null);
        tag.background_rgba = Gdk.RGBA() { red = 1.0, green = 1.0, blue = 0, alpha = 0.8 };
        tag = srcbuf.create_tag ("symbol_used", null);
        tag.background_rgba = Gdk.RGBA() { red = 0, green = 0, blue = 0, alpha = 0.2 };

        if (project != null)
            foreach (var err in project.get_errorlist())
                if (err.source.file.filename == filename)
                    apply_annotation (view, srcbuf, err);

        /* Statusbar */
        var statusbar = new Statusbar();
        vbox.pack_start (statusbar, false);

        var lbl = new Label (_("Language: "));
        statusbar.pack_start (lbl, false);

        var cbox = new ComboBoxText();
        statusbar.pack_start (cbox, false);
        cbox.append_text (lang_fallback);

        foreach (var lang_id in langman.get_language_ids())
            cbox.append_text (langman.get_language (lang_id).name);

        string? lang_selected;
        var lang = ((SourceBuffer) view.buffer).language;
        if (lang != null) {
            lang_selected = langman.get_language (lang.id).name;
            cbox.active = langmap[lang_selected].value;
        } else {
            cbox.active = 0;
            lang_selected = lang_fallback;
        }

        cbox.changed.connect (() => {
            var new_lang = cbox.get_active_text();

            if (new_lang == null)
                cbox.active = 0;

            if (new_lang != lang_selected) {
                if (langmap[lang_selected].key == "vala")
                    try {
                        view.completion.remove_provider (project.comp_provider);
                    } catch (GLib.Error e) {
                        errmsg (_("Could not unload completion: %s\n"), e.message);
                    }
                lang_selected = new_lang;
                if (lang_selected == null || langmap[lang_selected].key == "vala")
                    try {
                        view.completion.add_provider (project.comp_provider);
                    } catch (GLib.Error e) {
                        errmsg (_("Could not load completion: %s\n"), e.message);
                    }

                lang = (lang_selected != null) ? langman.get_language (langmap[lang_selected].key)
                                               : null;
                ((SourceBuffer) view.buffer).set_language (lang);
            }
        });

        var lgrid = new Grid();
        lgrid.valign = Align.CENTER;
        statusbar.pack_start (lgrid, false);

        var pos_col_lbl = new Label (get_label_row_col (view));
        pos_col_lbl.width_request = 100;
        lgrid.attach (pos_col_lbl, 0, 0, 1, 1);
        view.buffer.notify["cursor-position"].connect (() => {
            pos_col_lbl.label = get_label_row_col (view);
        });

        // TRANSLATORS: overwrite input mode
        var insmode_lbl = new Label ((view.overwrite) ? _("OVR")
        // TRANSLATORS: insert input mode
                                                      : _("INS"));
        insmode_lbl.width_request = 50;
        lgrid.attach (insmode_lbl, 1, 0, 1, 1);
        view.notify["overwrite"].connect (() => {
            insmode_lbl.label = (view.overwrite) ? _("OVR") : _("INS");
        });

        var sepu = new Separator (Orientation.HORIZONTAL);
        vbox.pack_start (sepu, false);

        /*
         * NOTE: Keep this in sync with get_sourceview method.
         */
        var item = new DockItem.with_stock ("SourceView " + srcitems.size.to_string(),
                                            displayname,
                                            (srcbuf.dirty) ? "gtk-new" : "gtk-edit",
                                            DockItemBehavior.LOCKED);
        srcbuf.notify["dirty"].connect (() => {
#if GDL_3_8 || GDL_3_9_91
            item.stock_id = (srcbuf.dirty) ? "gtk-new" : "gtk-edit";
#else
            /* Work around #695972 to update icon. */
            item.set ("stock-id", (srcbuf.dirty) ? "gtk-new" : "gtk-edit");
#endif
        });
        item.add (vbox);

        /* Set focus on tab change. */
        item.selected.connect (() => {
            this.current_srcfocus = filename;
        });
        /* Set focus on click. */
        view.grab_focus.connect (() => {
            this.current_srcfocus = filename;
        });

        if (srcitems.size == 0) {
            item.behavior |= DockItemBehavior.CANT_CLOSE;
            this.srcdock.add_item (item, DockPlacement.RIGHT);
        } else {
            /* Handle dock item closing. */
            item.hide.connect (() => {
                /* Suppress dialog by removing item at first from srcitems list. */
                if (!(item in srcitems))
                    return;
                /*
                 * TODO: Better solution to prevent emission of hiding? We
                 *       want hide it at a later point after confirm dialog.
                 */
                /*
                 * This will work properly with gdl-3.0 >= 3.5.5
                 */
                item.show_item();
#if !GDL_3_9_91
                set_notebook_tabs (item);
#endif

                if (buffer_close (get_sourceview (item), displayname)) {
                    close_srcitem_pr (item, filename);  // closes the item
                    project.close_viewbuffer (filename);
                }
            });

            item.behavior = DockItemBehavior.CANT_ICONIFY;

            /*
             * Hide default source view if it is empty.
             * Dock new items to focused dock item.
             *
             * NOTE: Custom unsaved views are ignored (even if empty).
             */
            int id = 0;
            if (this.current_srcfocus != null)
                id = get_sourceview_id (this.current_srcfocus);
            if (id != -1)
                this.srcitems[id].dock (item, DockPlacement.CENTER, 0);
            else {
                bug_msg (_("Source view id out of range.\n"));
                return;
            }
            if (srcitems.size == 1) {
                var view_widget = get_sourceview (srcitems[0]);
                //TODO: Use dirty flag of buffer.
                if (view_widget.buffer.text == "")
                    srcitems[0].hide_item();
            }
        }
        srcitems.add (item);
        item.show_all();

        /*
         * Set notebook tab properly if needed.
         */
#if !GDL_3_9_91
        item.dock.connect (() => {
            set_notebook_tabs (item);
        });
#endif
    }

    /**
     * Update row and column statusbar string.
     *
     * @param view Corresponding view with {@link Gtk.TextBuffer}.
     * @return Row and column info.
     */
    private inline string get_label_row_col (SourceView view) {
        TextIter iter;
        view.buffer.get_iter_at_mark (out iter, view.buffer.get_insert());
        var row = iter.get_line();
        var column = view.get_visual_column (iter);
        // TRANSLATORS: Short name for Line X, Column Y
        return _("Ln %d, Col %d").printf (row + 1, column + 1);
    }

    /**
     * Set up {@link Gtk.Notebook} tab properties.
     *
     * @param item {@link Gdl.DockItem} to setup.
     */
#if !GDL_3_9_91
    private void set_notebook_tabs (DockItem item) {
        var pa = item.parent;
        if (pa is Notebook) {
            var nbook = (Notebook) pa;
            nbook.set_tab_pos (PositionType.TOP);
            foreach (var child in nbook.get_children())
                nbook.set_tab_reorderable (child, true);
        }
    }
#endif

    /**
     * Get {@link Gtk.SourceView} from within {@link Gdl.DockItem}.
     *
     * @param item {@link Gdl.DockItem} to get {@link Gtk.SourceView} from.
     * @return Return associated {@link Gtk.SourceView}.
     */
    /*
     * NOTE: Be careful. This have to be exactly the same objects as the
     *       objects at creation of new source views.
     */
    private inline SuperSourceView get_sourceview (DockItem item) {
#if !GDL_LESS_3_5_5
        return (SuperSourceView) ((ScrolledWindow) ((Box) item.get_child()).get_children().nth_data (0)).get_child();
#else
        /*
         * Work arround GNOME #693127.
         */
        ScrolledWindow? scroll_widget = null;
        item.forall ((child) => {
            if (child is Box && ((Box) child).get_children().nth_data (0) is ScrolledWindow)
                scroll_widget = ((Box) child).get_children().nth_data (0) as ScrolledWindow;
        });
        if (scroll_widget == null)
            // TRANSLATORS: This is an technical information. You might not want
            // to translate "ScrolledWindow".
            bug_msg (_("Could not find ScrolledWindow widget: %s\n"), item.name);
        return (SuperSourceView) scroll_widget.get_child();
#endif
    }

    /**
     * Get id of {@link Gtk.SourceView} by filename.
     *
     * @param filename Name of source file to search for in {@link srcitems}.
     * @param warn `true` to warn if no such view.
     * @return If file was found return id of {@link Gtk.SourceView} in
     *         {@link srcitems}. Else -1.
     */
    private int get_sourceview_id (string filename, bool warn = true) {
        if (!is_new_document (filename)) {
            for (int i = 0; i < srcitems.size; ++i)
                if (project.get_absolute_path (srcitems[i].long_name) == filename)
                    return i;
        } else {
            for (int i = 0; i < srcitems.size; ++i)
                if (srcitems[i].long_name == filename)
                    return i;
        }
        if (warn)
            warning_msg (_("No such file found in opened buffers: %s\n"), filename);
        return -1;
    }

    /**
     * Set focus and insert mark to the given position and open file if
     * necessary.
     *
     * @param filename Name of file to switch to.
     * @param line Line where to jump.
     * @param col Column where to jump.
     * @param setcursor If `true` set cursor to position.
     * @param focus If `true` focus item.
     */
    public void jump_to_position (string filename, int line, int col,
                                  bool setcursor = true, bool focus = true) {
        on_file_selected (filename, focus);
        var srcbuffer = project.get_buffer_by_file (filename);
        if (srcbuffer == null)
            return;
        TextIter titer;
        srcbuffer.get_iter_at_line_offset (out titer, line, col);
        srcbuffer.select_range (titer, titer);
        var srcview = get_sourceview_by_file (filename);
        GLib.Idle.add(()=>{
            if (focus)
                srcview.grab_focus();
            srcview.scroll_to_iter (titer, 0.42, true, 1.0, 1.0);
            return false;
        });
        if (setcursor)
            srcbuffer.place_cursor (titer);
    }

    /**
     * Get {@link Gtk.SourceView} by filename.
     *
     * @param filename Name of source file.
     * @param warn `true` to warn if no such view.
     * @return If file was found return {@link Gtk.SourceView} object else
     *         null.
     */
    public SuperSourceView? get_sourceview_by_file (string filename, bool warn = true) {
        var id = get_sourceview_id (filename, warn);
        if (id == -1)
            return null;
        return get_sourceview (this.srcitems[id]);
    }

    public override void build() {
        debug_msg (_("Run %s update!\n"), get_name());
        debug_msg (_("%s update finished!\n"), get_name());
    }
}

public static inline bool is_new_document (string filename) {
    return filename.has_prefix (_("New document"));
}
