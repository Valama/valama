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

/**
 * Main window class. Setup {@link Gdl.Dock} and {@link Gdl.DockBar} stuff.
 */
class MainWindow : Window {
    private Dock dock;
    private DockLayout layout;
    private Toolbar toolbar;

    public MainWindow() {
        this.destroy.connect (Gtk.main_quit);
        this.title = _("Valama");
        this.hide_titlebar_when_maximized = true;
        this.maximize();
        //this.set_default_size (x,y);

        var vbox_main = new Box (Orientation.VERTICAL, 5);
        vbox_main.border_width = 10;
        add (vbox_main);


        /* Menubar. */
        toolbar = new Toolbar();
        vbox_main.pack_start (toolbar, false, true);

        /* Gdl dock stuff. */
        dock = new Dock();

        this.layout = new DockLayout (dock);

        var dockbar = new DockBar (dock);
        dockbar.set_style (DockBarStyle.TEXT);

        var box = new Box (Orientation.HORIZONTAL, 5);
        vbox_main.pack_start (box, true, true, 0);
        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);
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
