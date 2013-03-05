/*
 * src/main_widget.vala
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
using Gdl;
using Gee;

/**
 * Main window class. Setup {@link Gdl.Dock} and {@link Gdl.DockBar} stuff.
 */
public class MainWidget : Box {
    /**
     * Master dock for all items except tool and menubar.
     */
    private Dock dock;
    /**
     * Layout of master dock {@link dock}.
     */
    private DockLayout layout;
    /**
     * Menubar. Fill with {@link add_menu}.
     */
    private MenuBar menubar;
    /**
     * Toolbar. Fill with {@link add_button}.
     */
    private Toolbar toolbar;

    /**
     * Global shortcut object.
     */
    public AccelGroup accel_group;

    /**
     * Emit when widget can be closed.
     */
    public signal void request_close();

    /**
     * Emit to hide dock item grip (if not disabled).
     */
    public signal void lock_items();
    /**
     * Emit to show dock item grip.
     */
    public signal void unlock_items();

    /**
     * Create MainWindow. Initialize menubar, toolbar, master dock and source
     * dock.
     */
    public MainWidget() {
        this.destroy.connect (on_destroy);

        accel_group = new AccelGroup();

        this.orientation = Orientation.VERTICAL;
        this.spacing = 0;

        /* Menubar. */
        this.menubar = new MenuBar();
        this.pack_start (menubar, false, true);

        /* Toolbar. */
        this.toolbar = new Toolbar();
        this.pack_start (toolbar, false, true);
        var toolbar_scon = toolbar.get_style_context();
        toolbar_scon.add_class (STYLE_CLASS_PRIMARY_TOOLBAR);

        /* Gdl dock stuff. */
        this.dock = new Dock();
        this.layout = new DockLayout (this.dock);

        var dockbar = new DockBar (this.dock);
        dockbar.set_style (DockBarStyle.TEXT);

        var box = new Box (Orientation.HORIZONTAL, 5);
        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);
        this.pack_start (box, true, true, 0);
        box.show_all();
    }

    /**
     * Save gdl layout.
     */
    public void on_destroy() {
        var local_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                     Environment.get_user_cache_dir(),
                                                     "valama",
                                                     "layout.xml");
        var f = File.new_for_path (local_layout_filename).get_parent();
        if (!f.query_exists())
            try {
                f.make_directory_with_parents();
            } catch (GLib.Error e) {
                errmsg (_("Couldn't create cache directory: %s\n"), e.message);
            }
        save_layout (local_layout_filename);
    }

    /**
     * Add new item to master dock {@link dock}.
     *
     * @param item_name Unique name of new {@link Gdl.DockItem}.
     * @param item_long_name Display name of new {@link Gdl.DockItem}.
     * @param widget {@link Gtk.Widget} to add to new {@link Gdl.DockItem}.
     * @param stock {@link Gtk.Stock} name to add icon to {@link Gdl.DockItem}.
     * @param behavior {@link Gdl.DockItemBehavior} of new {@link Gdl.DockItem}.
     * @param placement {@link Gdl.DockPlacement} of new {@link Gdl.DockItem}.
     */
    public void add_item (string item_name, string item_long_name,
                          UiElement element,
                          string? stock = null,
                          DockItemBehavior behavior = DockItemBehavior.NORMAL,
                          DockPlacement placement = DockPlacement.LEFT) {
        DockItem item;
        if (stock ==  null)
            item = new DockItem (item_name, item_long_name, behavior);
        else
            item = new DockItem.with_stock (item_name, item_long_name, stock, behavior);
        item.add (element.widget);
        element.dock_item = item;
        this.dock.add_item (item, placement);
        item.show();
    }

    /**
     * Add {@link UiElement} toggle item to menu.
     *
     * @param menu_view View (sub)menu.
     * @param element {@link UiElement} to connect toggle signals with.
     * @param label Description to show in menu.
     * @param with_mnemonic If true enable mnemonic.
     * @param key Accelerator {@linkGdl.Key} or null if none.
     * @param modtype Modifier type e.g. {@link Gdk.ModifierType.CONTROL_MASK} for ctrl.
     */
    public void add_view_menu_item (Gtk.Menu menu_view,
                                    UiElement element,
                                    string label,
                                    bool with_mnemonic = false,
                                    int? key = null,
                                    Gdk.ModifierType modtype = Gdk.ModifierType.CONTROL_MASK) {
        CheckMenuItem item_view_element;
        if (with_mnemonic)
            item_view_element = new CheckMenuItem.with_mnemonic (@"_$label");
        else
            item_view_element = new CheckMenuItem.with_label (label);
#if GDL_3_6_2
        item_view_element.active = !element.dock_item.is_closed();
#else
        item_view_element.active = ((element.dock_item.flags & DockObjectFlags.ATTACHED) != 0);
#endif
        menu_view.append (item_view_element);

        item_view_element.toggled.connect (() => {
            element.show_element (item_view_element.active);
        });
        element.show_element.connect ((show) => {
            if (show != item_view_element.active)
                item_view_element.active = show;
        });

        if (key != null)
            add_accel_activate (item_view_element, key, modtype, "activate");
    }

    /**
     * Add {@link UiElement} toggle item to toolbar.
     *
     * @param toolbar Toolbar to add button.
     * @param element {@link UiElement} to connect toggle signals with.
     * @param stock_id Stock item.
     * @param icon_name Icon from theme.
     */
    public void add_view_toolbar_item (UiElement element,
                                       string? stock_id,
                                       string? icon_name)
                    requires (stock_id != null || icon_name != null) {
        ToggleToolButton btn_element;
        if (stock_id != null)
            btn_element = new ToggleToolButton.from_stock (stock_id);
        else {
            btn_element = new ToggleToolButton();
            btn_element.icon_name = icon_name;
        }
        toolbar.add (btn_element);
        btn_element.show();

#if GDL_3_6_2
        btn_element.active = !element.dock_item.is_closed();
#else
        btn_element.active = ((element.dock_item.flags & DockObjectFlags.ATTACHED) != 0);
#endif
        btn_element.toggled.connect (() => {
            element.show_element (btn_element.active);
        });
        element.show_element.connect ((show) => {
            if (show != btn_element.active)
                btn_element.active = show;
        });
    }

    /**
     * Add menu to main {@link Gtk.MenuBar}.
     *
     * @param item {@link Gtk.MenuItem} to add.
     */
    public void add_menu (Gtk.MenuItem item) {
        menubar.add (item);
    }

    /**
     * Show all menu items.
     */
    public inline void menu_finish() {
        menubar.show_all();
    }

    /**
     * Add new button to main {@link Gdl.DockBar}.
     *
     * @param item {@link Gtk.ToolItem} to add.
     */
    public void add_button (ToolItem item) {
        toolbar.add (item);
    }

    /**
     * Show all menu items.
     */
    public inline void toolbar_finish() {
        toolbar.show_all();
    }

    /**
     * Save current {@link Gdl.DockLayout} to file.
     *
     * @param  filename Name of file to save layout to.
     * @param section Save specific layout section.
     * @return Return true on success else false.
     */
    public bool save_layout (string filename, string section = "__default__") {
        this.layout.save_layout (section);
        bool ret = this.layout.save_to_file (filename);
        if (!ret)
            errmsg (_("Couldn't save layout to file: %s\n"), filename);
        else
            debug_msg (_("Layout '%s' saved to file: %s\n"), section, filename);
        return ret;
    }

    /**
     * Load {@link Gdl.DockLayout} from filename.
     *
     * @param filename Name of file to load layout from.
     * @param section Name of default section to load settings from.
     * @param error Display error if layout file loading failed.
     * @return Return true on success else false.
     */
    public bool load_layout (string filename,
                             string? section = null,
                             bool error = true) {
        string lsection = (section != null) ? section : "__default__";
        bool ret = this.layout.load_from_file (filename);
        if (ret)
            debug_msg (_("Layouts loaded from file: %s\n"), filename);
        else if (error)
            errmsg (_("Couldn't load layout file: %s\n"), filename);
        return (ret && this.layout_reload (lsection));
    }

    /**
     * Reload current {@link Gdl.DockLayout}. May be helpful on window resize.
     *
     * @param section Name of default section to load settings from.
     * @return Return true on success else false.
     */
    public bool layout_reload (string section = "__default__") {
        bool ret = this.layout.load_layout (section);
        if (!ret)
            errmsg (_("Couldn't load layout: %s\n"), section);
        else
            debug_msg (_("Layout loaded: %s\n"), section);
        return ret;
    }

    /**
     * Focus a {@link Gdl.DockItem}.
     *
     * @param item The item to recveive focus.
     */
    public void focus_dock_item (DockItem item) {
        /* Hack arround gdl_dock_notebook with gtk_notebook. */
        var pa = item.parent;
        /* If something strange happens (pa == null) break the loop. */
        while (!(pa is Dock) && (pa != null)) {
            if (pa is Notebook) {
                var nbook = (Notebook) pa;
                nbook.page = nbook.page_num (item);
            }
            pa = pa.parent;
        }
    }


    /**
     * Add accelerator for "activate" signal.
     *
     * @param item {@link Gtk.Widget} to connect.
     * @param keyname Name of key to connect to signal (with modtype).
     * @param modtype {@link Gdk.ModifierType} to connect to signal together
     *                with keyname. Default modifier key is "ctrl".
     */
    public void add_accel_activate (Widget item,
                                    int key,
                                    Gdk.ModifierType modtype = Gdk.ModifierType.CONTROL_MASK,
                                    string signal_name = "activate") {
        item.add_accelerator (signal_name,
                              this.accel_group,
                              key,
                              modtype,
                              AccelFlags.VISIBLE);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
