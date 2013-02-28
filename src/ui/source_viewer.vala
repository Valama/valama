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
     * List of all {@link DockItem} objects in source dock {@link srcdock}.
     */
    private ArrayList<DockItem> srcitems = new ArrayList<DockItem>();

    private string? _current_srcfocus = null;
    /**
     * Relative path to current selected {@link SourceBuffer}.
     */
    public string current_srcfocus {
        get {
            return _current_srcfocus;
        }
        private set {
            debug_msg (_("Change current focus: %s\n"), value);
            bool emit_sourceview_changed = this._current_srcfocus != value;

            this._current_srcfocus = value;
            this.current_srcid = get_sourceview_id (value);
            if (0 <= this.current_srcid < this.srcitems.size) {
                this.current_srcview = get_sourceview (this.srcitems[this.current_srcid]);
                this.current_srcbuffer = (SourceBuffer) this.current_srcview.buffer;
            } else
                warning_msg (_("Could not select current source view: %s\n" +
                             "Expected behavior may change.\n"), this._current_srcfocus);
            if (emit_sourceview_changed)
                current_sourceview_changed();
        }
    }
    /**
     * Id of current {@link Gtk.SourceView} in {@link srcitems}.
     */
    private int current_srcid { get; private set; default = -1; }
    /**
     * Currently selected {@link Gtk.SourceView}.
     */
    public SourceView? current_srcview { get; private set; default = null; }
    /**
     * Currently selected {@link SourceBuffer}.
     */
    public SourceBuffer? current_srcbuffer { get; private set; default = null; }
    /**
     * Gets emitted when another sourceview is selected
     */
    public signal void current_sourceview_changed();

    /**
     * Create source viewer object and initialize {@link Gdl.Dock}.
     */
    public UiSourceViewer() {
        locking = false;

        srcdock = new Dock();
        this.srcdock.master.switcher_style = SwitcherStyle.TABS;
        this.srclayout = new DockLayout (this.srcdock);

        widget = new Box (Orientation.HORIZONTAL, 0);
        ((Box)widget).pack_end (this.srcdock);
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
                    get_sourceview(srcitem).grab_focus();
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
     * @return Return false to interrupt or return true proceed.
     */
    public signal bool buffer_close (SourceView view);

    /**
     * Hide (close) {@link Gdl.DockItem} with {@link Gtk.SourceView} by
     * filename.
     *
     * @param filename Absolute name of source file to close.
     */
    public void close_srcitem (string filename) {
        foreach (var srcitem in srcitems)
            if (project.get_absolute_path (srcitem.long_name) == filename) {
                srcitems.remove (srcitem);
                srcitem.hide_item();
            }
    }

    /**
     * Add new source view item to source dock {@link srcdock}.
     *
     * @param view {@link Gtk.SourceView} object to add.
     * @param filepath Name of file (used to identify item).
     */
    public void add_srcitem (SourceView view, string filepath = "") {
        string displayname, filename = filepath;
        if (filename == "") {
            displayname = filename = _("New document");

        } else {
            filename = project.get_absolute_path (filename);
            displayname = project.get_relative_path (filename);
        }

        var src_view = new ScrolledWindow (null, null);
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
        /*
         * NOTE: Keep this in sync with get_sourceview method.
         */
        var item = new DockItem.with_stock ("SourceView " + srcitems.size.to_string(),
                                            displayname,
                                            (srcbuf.dirty) ? Stock.NEW : Stock.EDIT,
                                            DockItemBehavior.LOCKED);
        srcbuf.notify["dirty"].connect ((sender, property) => {
            item.stock_id = (srcbuf.dirty) ? Stock.NEW : Stock.EDIT;
        });
        item.add (src_view);

        /* Set focus on tab change. */
        item.selected.connect (() => {
            this.current_srcfocus = filename;
        });
        /* Set focus on click. */
        view.grab_focus.connect (() => {
            this.current_srcfocus = filename;
        });


        if (srcitems.size == 0) {
            this.srcdock.add_item (item, DockPlacement.RIGHT);
        } else {
            /* Handle dock item closing. */
            item.hide.connect (() => {
                /* Suppress dialog by removing item at first from srcitems list. */
                if (!(item in srcitems))
                    return;

                if (!buffer_close (get_sourceview (item))) {
                    /*
                     * This will work properly with gdl-3.0 >= 3.5.5
                     */
                    item.show_item();
                    set_notebook_tabs (item);
                    return;
                }
                srcitems.remove (item);
                if (srcitems.size == 1)
                    srcitems[0].show_item();
            });

            item.behavior = DockItemBehavior.CANT_ICONIFY;

            /*
             * Hide default source view if it is empty.
             * Dock new items to focused dock item.
             *
             * NOTE: Custom unsafed views are ignored (even if empty).
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
        item.dock.connect (() => {
            set_notebook_tabs (item);
        });

    }

    /**
     * Set up {@link Gtk.Notebook} tab properties.
     *
     * @param item {@link Gdl.DockItem} to setup.
     */
    private void set_notebook_tabs (DockItem item) {
        var pa = item.parent;
        if (pa is Notebook) {
            var nbook = (Notebook) pa;
            nbook.set_tab_pos (PositionType.TOP);
            foreach (var child in nbook.get_children())
                nbook.set_tab_reorderable (child, true);
        }
    }

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
    private SourceView get_sourceview (DockItem item) {
#if VALA_0_20
        var scroll_widget = (ScrolledWindow) item.get_child();
#else
        /*
         * Work arround GNOME #693127.
         */
        ScrolledWindow scroll_widget = null;
        item.forall ((child) => {
            if (child is ScrolledWindow)
                scroll_widget = (ScrolledWindow) child;
        });
        if (scroll_widget == null)
            bug_msg (_("Could not find ScrolledWindow widget: %s\n"), item.name);
#endif
        return (SourceView) scroll_widget.get_children().nth_data (0);
    }

    /**
     * Get id of {@link Gtk.SourceView} by filename.
     *
     * @param filename Name of source file to search for in {@link srcitems}.
     * @return If file was found return id of {@link Gtk.SourceView} in
     *         {@link srcitems}. Else -1.
     */
    private int get_sourceview_id (string filename) {
        if (filename != _("New document")) {
            for (int i = 0; i < srcitems.size; ++i)
                if (project.get_absolute_path (srcitems[i].long_name) == filename)
                    return i;
        } else {
            for (int i = 0; i < srcitems.size; ++i)
                if (srcitems[i].long_name == filename)
                    return i;
        }
        warning_msg (_("No such file found in opened buffers: %s\n"), filename);
        return -1;
    }

    /**
     * Set focus and insert mark to the given position and open file if
     * necessary.
     *
     * @param filename Name of file to switch to.
     * @param line Line where to jump.
     * @param setcursor If true set cursor to position.
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
     * @return If file was found return {@link Gtk.SourceView} object else
     *         null.
     */
    public SourceView? get_sourceview_by_file (string filename) {
        var id = get_sourceview_id (filename);
        if (id == -1)
            return null;
        return get_sourceview (this.srcitems[id]);
    }

    public override void build() {
        debug_msg (_("Run %s update!\n"), get_name());
        debug_msg (_("%s update finished!\n"), get_name());
    }
}
