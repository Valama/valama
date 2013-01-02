/*
 * src/ui_main.vala
 * Copyright (C) 2012, Dominique Lasserre <lasserre.d@gmail.com>
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
 * Main window class. Setup {@link Gdl.Dock} and {@link Gdl.DockBar} stuff.
 */
class MainWindow : Window {
    private Dock dock;
    private DockLayout layout;
    private Toolbar toolbar;

    private Dock srcdock;
    private DockLayout srclayout;
    private ArrayList<DockItem> srcitems;

    public string current_srcfocus { get; private set; }

    public MainWindow() {
        this.destroy.connect (Gtk.main_quit);
        this.title = _("Valama");
        this.hide_titlebar_when_maximized = true;
        this.set_default_size (1200, 600);
        this.maximize();

        var vbox_main = new Box (Orientation.VERTICAL, 5);
        vbox_main.border_width = 10;
        add (vbox_main);


        /* Menubar. */
        this.toolbar = new Toolbar();
        vbox_main.pack_start (toolbar, false, true);

        /* Gdl dock stuff. */
        this.dock = new Dock();

        this.layout = new DockLayout (this.dock);

        var dockbar = new DockBar (this.dock);
        dockbar.set_style (DockBarStyle.TEXT);

        var box = new Box (Orientation.HORIZONTAL, 5);
        vbox_main.pack_start (box, true, true, 0);
        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);

        this.srcitems = new ArrayList<DockItem>();
    }

    /**
     * Focus source view {@link Gdl.DockItem} in {@link Gdl.Dock} and select
     * recursively all {@link Gdl.DockNotebook} tabs.
     */
    public void focus_src (string filename) {
        foreach (var srcitem in srcitems) {
            if (srcitem.long_name == filename) {
                /* Hack arround gdl_dock_notebook with gtk_notebook. */
                var pa = srcitem.parent;
                // pa.grab_focus();
                /* If something strange happens (pa == null) break the loop. */
                while (!(pa is Dock) && (pa != null)) {
                    //stdout.printf("item: %s\n", pa.name);
                    if (pa is Switcher) {
                        var nbook = (Notebook) pa;
                        nbook.page = nbook.page_num (srcitem);
                    }
                    pa = pa.parent;
                    // pa.grab_focus();
                }
                return;
            }
        }
    }

    /**
     * Connect to this signal to interrupt hiding (closing) of
     * {@link Gdl.DockItem} with {@link Gtk.SourceView}.
     *
     * Return false to interrupt or return true proceed.
     */
    public signal bool buffer_close (SourceView view);

    /**
     * Hide (close) {@link Gdl.DockItem} with {@link Gtk.SourceView} by
     * filename.
     */
    public void close_srcitem (string filename) {
        foreach (var srcitem in srcitems)
            if (srcitem.long_name == filename) {
                srcitems.remove (srcitem);
                srcitem.hide_item();
            }
    }

    /**
     * Add new source view item to main {@link Gdl.Dock}.
     */
    public void add_srcitem (SourceView view, string filename = "") {
        if (filename == "")
            filename = _("New document");

        var src_view = new ScrolledWindow (null, null);
        src_view.add (view);
        var item = new DockItem.with_stock ("SourceView " + srcitems.size.to_string(),
                                            filename,
                                            Stock.EDIT,
                                            DockItemBehavior.LOCKED);
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
            this.srcdock = new Dock();
            this.srclayout = new DockLayout (this.srcdock);
            var box = new Box (Orientation.HORIZONTAL, 0);
            box.pack_end (this.srcdock);

            /* Don't make source view dockable. */
            var boxitem = new DockItem ("SourceView",  _("Source"),
                                        DockItemBehavior.NO_GRIP |
                                        DockItemBehavior.CANT_DOCK_TOP |
                                        DockItemBehavior.CANT_DOCK_BOTTOM |
                                        DockItemBehavior.CANT_DOCK_LEFT |
                                        DockItemBehavior.CANT_DOCK_RIGHT |
                                        DockItemBehavior.CANT_DOCK_CENTER);
            boxitem.add (box);
            this.dock.add_item (boxitem, DockPlacement.TOP);

            this.srcdock.add_item (item, DockPlacement.RIGHT);
            this.srcdock.master.switcher_style = SwitcherStyle.TABS;
        } else {
            /* Handle dock item closing. */
            item.hide.connect (() => {
                /* Suppress dialog by removing item first forom srcitems list.  */
                if (!(item in srcitems))
                    return;

                if (!buffer_close (get_sourceview (item))) {
                    /*
                     * This will work properly with gdl-3.0 >= 3.6
                     */
                    item.show_item();
                    var pa = item.parent;
                    if (pa is Switcher) {
                        var nbook = (Notebook) pa;
                        nbook.set_tab_pos (PositionType.TOP);
                        foreach (var child in nbook.get_children())
                            nbook.set_tab_reorderable (child, true);
                    }
                    return;
                }
                srcitems.remove (item);
                if (srcitems.size == 1)
                    srcitems[0].show_item();
            });

            item.behavior = DockItemBehavior.CANT_ICONIFY;

            /*
             * Hide default source view if it is empty.
             * Dock new items to first dock item.
             *
             * NOTE: Custom unsafed views are ignored (even if empty).
             */
            //TODO: Test whether docking to first or last added item is more intuitive.
            if (srcitems.size == 1) {
                this.srcitems[0].dock (item, DockPlacement.CENTER, 0);

                var view_widget = get_sourceview (srcitems[0]);
                if (view_widget.buffer.text == "")
                    srcitems[0].hide_item();
            } else
                this.srcitems[1].dock (item, DockPlacement.CENTER, 0);

            var pa = item.parent;
            if (pa is Switcher) {
                var nbook = (Notebook) pa;
                nbook.set_tab_pos (PositionType.TOP);
                foreach (var child in nbook.get_children())
                    nbook.set_tab_reorderable (child, true);
            }
        }
        srcitems.add (item);
        view.show();
        src_view.show();
        item.show();
    }

    /**
     * Get {@link Gtk.SourceView} from within {@link Gdl.DockItem}.
     *
     */
    /*
     * Be careful. This have to be exactly the same objects as
     * the objects at creation of new source views.
     */
    private SourceView get_sourceview (DockItem item) {
        var scroll_widget = (ScrolledWindow) item.child;
        return (SourceView) scroll_widget.get_children().nth_data (0);
    }

    /**
     * Add new item to main {@link Gdl.Dock}.
     */
    public void add_item (string item_name, string item_long_name,
                          Widget widget,
                          string? stock = null,
                          DockItemBehavior behavior,
                          DockPlacement placement) {
        DockItem item;
        if (stock ==  null)
            item = new DockItem (item_name, item_long_name, behavior);
        else
            item = new DockItem.with_stock (item_name, item_long_name, stock, behavior);
        item.add (widget);
        this.dock.add_item (item, placement);
        item.show();
    }

    /**
     * Add new button to main {@link Gdl.DockBar}.
     */
    public void add_button (ToolButton button){
        toolbar.add (button);
    }

    /**
     * Save current {@link Gdl.DockLayout} to file.
     */
    public bool save_layout (string filename) {
        bool ret = this.layout.save_to_file (filename);
        if (!ret)
            stderr.printf (_("Couldn't save layout to file: %s\n"), filename);
#if DEBUG
        else
            stdout.printf (_("Layout saved to file: %s\n"), filename);
#endif
        return ret;
    }

    /**
     * Load {@link Gdl.DockLayout} from filename.
     */
    public bool load_layout (string filename, string section = "__default__") {
        bool ret = this.layout.load_from_file (filename);
        if (!ret)
            stderr.printf (_("Couldn't load layout file: %s\n"), filename);
#if DEBUG
        else
            stdout.printf (_("Layout loaded from file: %s\n"), filename);
#endif
        return (ret && this.layout_reload (section));
    }

    /**
     * Reload current {@link Gdl.DockLayout}. May be helpful on window resize.
     */
    public bool layout_reload (string section = "__default__") {
        bool ret = this.layout.load_layout (section);
        if (!ret)
            stderr.printf (_("Couldn't load layout: %s\n"), section);
#if DEBUG
        else
            stdout.printf (_("Layout loaded: %s\n"), section);
#endif
        return ret;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
