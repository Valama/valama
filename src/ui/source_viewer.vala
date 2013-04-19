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
        this.srcdock.master.switcher_style = SwitcherStyle.TABS;
#if GDL_3_8_2
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

        widget = vbox;
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
    public void add_srcitem (SourceView view, string filepath = "") {
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
        attr.stock_id = Stock.MEDIA_FORWARD;
        view.set_mark_attributes ("timer", attr, 0);
        var attr2 = new SourceMarkAttributes();
        attr2.stock_id = Stock.STOP;
        view.set_mark_attributes ("stop", attr2, 0);
        view.show_line_marks = true;
        TextTag tag = srcbuf.create_tag ("error_bg", null);
        tag.underline = Pango.Underline.ERROR;
        tag = srcbuf.create_tag ("warning_bg", null);
        tag.background_rgba = Gdk.RGBA() { red = 1.0, green = 1.0, blue = 0, alpha = 0.8 };
        tag = srcbuf.create_tag ("search", null);
        tag.background_rgba = Gdk.RGBA() { red = 1.0, green = 1.0, blue = 0.8, alpha = 1.0 };

        //"left-margin", "1", "left-margin-set", "true",

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

        var sepu = new Separator (Orientation.HORIZONTAL);
        vbox.pack_start (sepu, false);

        /*
         * NOTE: Keep this in sync with get_sourceview method.
         */
        var item = new DockItem.with_stock ("SourceView " + srcitems.size.to_string(),
                                            displayname,
                                            (srcbuf.dirty) ? Stock.NEW : Stock.EDIT,
                                            DockItemBehavior.LOCKED);
        srcbuf.notify["dirty"].connect (() => {
            /* Work around #695972 to update icon. */
            //item.stock_id = (srcbuf.dirty) ? Stock.NEW : Stock.EDIT;
            item.set ("stock-id", (srcbuf.dirty) ? Stock.NEW : Stock.EDIT);
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
#if !GDL_3_8_2
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
#if !GDL_3_8_2
        item.dock.connect (() => {
            set_notebook_tabs (item);
        });
#endif
    }

    /**
     * Set up {@link Gtk.Notebook} tab properties.
     *
     * @param item {@link Gdl.DockItem} to setup.
     */
#if !GDL_3_8_2
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
#if VALAC_0_20 && !GDL_LESS_3_5_5
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
     * @param setcursor If `true` set cursor to position.
     * @param col Column where to jump.
     */
    public void jump_to_position (string filename, int line, int col, bool setcursor = true) {
        on_file_selected (filename);
        var srcbuffer = project.get_buffer_by_file (filename);
        if (srcbuffer == null)
            return;
        TextIter titer;
        srcbuffer.get_iter_at_line_offset (out titer, line, col);
        srcbuffer.select_range (titer, titer);
        var srcview = get_sourceview_by_file (filename);
        GLib.Idle.add(()=>{
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
