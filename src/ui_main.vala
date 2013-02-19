/*
 * src/ui_main.vala
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
public class MainWindow : Window {
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
    private AccelGroup accel_group;

    /**
     * Create MainWindow. Initialize menubar, toolbar, master dock and source
     * dock.
     */
    public MainWindow() {
        this.destroy.connect (main_quit);
        this.title = _("Valama");
        this.hide_titlebar_when_maximized = true;
        this.set_default_size (1200, 600);
        this.maximize();

        accel_group = new AccelGroup();
        this.add_accel_group (accel_group);

        var vbox_main = new Box (Orientation.VERTICAL, 0);
        this.add (vbox_main);

        /* Menubar. */
        this.menubar = new MenuBar();
        vbox_main.pack_start (menubar, false, true);

        /* Toolbar. */
        this.toolbar = new Toolbar();
        vbox_main.pack_start (toolbar, false, true);
        var toolbar_scon = toolbar.get_style_context();
        toolbar_scon.add_class (STYLE_CLASS_PRIMARY_TOOLBAR);

        /* Gdl dock stuff. */
        this.dock = new Dock();
        this.layout = new DockLayout (this.dock);

        var dockbar = new DockBar (this.dock);
        dockbar.set_style (DockBarStyle.TEXT);

        var box = new Box (Orientation.HORIZONTAL, 5);
        vbox_main.pack_start (box, true, true, 0);
        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);
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
     * Add menu to main {@link Gtk.MenuBar}.
     *
     * @param item {@link Gtk.MenuItem} to add.
     */
    public void add_menu (Gtk.MenuItem item) {
        this.menubar.add (item);
    }

    /**
     * Add new button to main {@link Gdl.DockBar}.
     *
     * @param item {@link Gtk.ToolItem} to add.
     */
    public void add_button (ToolItem item) {
        this.toolbar.add (item);
    }

    /**
     * Save current {@link Gdl.DockLayout} to file.
     *
     * @param  filename Name of file to save layout to.
     * @return Return true on success else false.
     */
    public bool save_layout (string filename) {
        bool ret = this.layout.save_to_file (filename);
        if (!ret)
            errmsg (_("Couldn't save layout to file: %s\n"), filename);
        else
            debug_msg (_("Layout saved to file: %s\n"), filename);
        return ret;
    }

    /**
     * Load {@link Gdl.DockLayout} from filename.
     *
     * @param filename Name of file to load layout from.
     * @param section Name of default section to load settings from.
     * @return Return true on success else false.
     */
    public bool load_layout (string filename, string section = "__default__") {
        bool ret = this.layout.load_from_file (filename);
        if (!ret)
            errmsg (_("Couldn't load layout file: %s\n"), filename);
        else
            debug_msg (_("Layout loaded from file: %s\n"), filename);
        return (ret && this.layout_reload (section));
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
     * Add accelerator for "activate" signal.
     *
     * @param item {@link Gtk.Widget} to connect.
     * @param keyname Name of key to connect to signal (with modtype).
     * @param modtype {@link Gdk.ModifierType} to connect to signal together
     *                with keyname. Default modifier key is "ctrl".
     */
    public void add_accel_activate (Widget item,
                                    string keyname,
                                    Gdk.ModifierType modtype = Gdk.ModifierType.CONTROL_MASK) {
        item.add_accelerator ("activate",
                              this.accel_group,
                              Gdk.keyval_from_name (keyname),
                              modtype,
                              AccelFlags.VISIBLE);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
