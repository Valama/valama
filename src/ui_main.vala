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

static ValamaProject project;
static Guanako.FrankenStein frankenstein;

static bool parsing = false;
static MainLoop loop_update;

//FIXME: Avoid those globals with signals.
static ProjectBrowser pbrw;
static ReportWrapper report_wrapper;
static UiReport wdg_report;
static ProjectBuilder project_builder;
static UiSourceViewer source_viewer;
static UiElementPool ui_elements_pool;
static BuildOutput build_output;

static Gee.HashMap<string, Gdk.Pixbuf> map_icons;


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

    string local_layout_filename;

    /**
     * Create MainWindow. Initialize menubar, toolbar, master dock and source
     * dock.
     */
    public MainWidget() {
        this.destroy.connect (on_destroy);

        accel_group = new AccelGroup();

        var vbox_main = new Box (Orientation.VERTICAL, 0);
        this.pack_start (vbox_main, true, true);

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
        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);
        vbox_main.pack_start (box, true, true, 0);

        /* Ui elements. */
        ui_elements_pool = new UiElementPool();
        pbrw = new ProjectBrowser (project);
        pbrw.file_selected.connect (on_file_selected);

        var smb_browser = new SymbolBrowser();
        pbrw.connect (smb_browser);
        ui_elements_pool.add (pbrw);

        report_wrapper = new ReportWrapper();
        project.guanako_project.set_report_wrapper (report_wrapper);
        wdg_report = new UiReport (report_wrapper);
        var wdg_breakpoints = new UiBreakpoints (frankenstein);

        ui_elements_pool.add (wdg_report);

        /* Gdl elements. */
        var src_symbol = new ScrolledWindow (null, null);
        src_symbol.add (smb_browser.widget);

        var src_report = new ScrolledWindow (null, null);
        src_report.add (wdg_report.widget);

        var wdg_current_file_structure = new UiCurrentFileStructure();
        var wdg_search = new UiSearch();
        var wdg_stylechecker = new UiStyleChecker();

        /* Init new empty buffer. */
        source_viewer.add_srcitem (project.open_new_buffer ("", "", true));
        add_item ("SourceView", _("Source view"), source_viewer.widget,
                              null,
                              DockItemBehavior.NO_GRIP | DockItemBehavior.CANT_DOCK_CENTER |
                              DockItemBehavior.CANT_CLOSE,
                              DockPlacement.TOP);
        add_item ("ReportWrapper", _("Report widget"), src_report,
                              Stock.INFO,
                              DockItemBehavior.CANT_CLOSE, //temporary solution until items can be added later
                              //DockItemBehavior.NORMAL,  //TODO: change this behaviour for all widgets
                              DockPlacement.BOTTOM);
        add_item ("ProjectBrowser", _("Project browser"), pbrw.widget,
                              Stock.FILE,
                              DockItemBehavior.CANT_CLOSE,
                              DockPlacement.LEFT);
        add_item ("BuildOutput", _("Build output"), build_output.widget,
                              Stock.FILE,
                              DockItemBehavior.CANT_CLOSE,
                              DockPlacement.LEFT);
        add_item ("Search", _("Search"), wdg_search.widget,
                              Stock.FIND,
                              DockItemBehavior.CANT_CLOSE,
                              DockPlacement.LEFT);
        add_item ("Breakpoints", _("Breakpoints / Timers"), wdg_breakpoints.widget,
                              Stock.FILE,
                              DockItemBehavior.CANT_CLOSE,
                              DockPlacement.LEFT);
        add_item ("CurrentFileStructure", _("Current file"), wdg_current_file_structure.widget,
                              Stock.FILE,
                              DockItemBehavior.CANT_CLOSE,
                              DockPlacement.LEFT);
        add_item ("StyleChecker", _("Coding style checker"), wdg_stylechecker.widget,
                              Stock.COLOR_PICKER,
                              DockItemBehavior.CANT_CLOSE,
                              DockPlacement.LEFT);
        add_item ("SymbolBrowser", _("Symbol browser"), src_symbol,
                              Stock.CONVERT,
                              DockItemBehavior.CANT_CLOSE,
                              DockPlacement.RIGHT);

        build_toolbar();
        build_menu();

        /* Load default layout. Either local one or system wide. */

        if (Args.layoutfile == null)
            local_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                     Environment.get_user_cache_dir(),
                                                     "valama",
                                                     "layout.xml");
        else
            local_layout_filename = Args.layoutfile;
        string system_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                         Config.PACKAGE_DATA_DIR,
                                                         "layout.xml");
        if (Args.reset_layout || !load_layout (local_layout_filename))
            load_layout (system_layout_filename);

        this.show_all();
    }
    void on_destroy() {
        var f = File.new_for_path (local_layout_filename).get_parent();
        if (!f.query_exists())
            try {
                f.make_directory_with_parents();
            } catch (GLib.Error e) {
                errmsg (_("Couldn't create cache directory: %s\n"), e.message);
            }
        save_layout (local_layout_filename);
    }

    void build_menu() {
        /* File */
        var item_file = new Gtk.MenuItem.with_mnemonic ("_" + _("File"));
        add_menu (item_file);

        var menu_file = new Gtk.Menu();
        item_file.set_submenu (menu_file);

        var item_new = new ImageMenuItem.from_stock (Stock.NEW, null);
        menu_file.append (item_new);
        item_new.activate.connect (create_new_file);
        add_accel_activate (item_new, "n");

        var item_open = new ImageMenuItem.from_stock (Stock.OPEN, null);
        menu_file.append (item_open);
        item_open.activate.connect (() => {
            ui_load_project (ui_elements_pool);
        });
        add_accel_activate (item_open, "o");

        var item_save = new ImageMenuItem.from_stock (Stock.SAVE, null);
        menu_file.append (item_save);
        item_save.activate.connect (() => {
            project.buffer_save();
        });
        project.buffer_changed.connect (item_save.set_sensitive);
        add_accel_activate (item_save, "s");

        menu_file.append (new SeparatorMenuItem());

        var item_quit = new ImageMenuItem.from_stock (Stock.QUIT, null);
        menu_file.append (item_quit);
        item_quit.activate.connect (main_quit);
        add_accel_activate (item_quit, "q");

        /* Edit */
        var item_edit = new Gtk.MenuItem.with_mnemonic ("_" + _("Edit"));
        add_menu (item_edit);
        var menu_edit = new Gtk.Menu();
        item_edit.set_submenu (menu_edit);

        var item_undo = new ImageMenuItem.from_stock (Stock.UNDO, null);
        item_undo.set_sensitive (false);
        menu_edit.append (item_undo);
        item_undo.activate.connect (undo_change);
        project.undo_changed.connect (item_undo.set_sensitive);
        add_accel_activate (item_undo, "u");

        var item_redo = new ImageMenuItem.from_stock (Stock.REDO, null);
        item_redo.set_sensitive (false);
        menu_edit.append (item_redo);
        item_redo.activate.connect (redo_change);
        project.redo_changed.connect (item_redo.set_sensitive);
        add_accel_activate (item_redo, "r");

        /* View */
        var item_view = new Gtk.MenuItem.with_mnemonic ("_" + _("View"));
        item_view.set_sensitive (false);
        add_menu (item_view);

        /* Project */
        var item_project = new Gtk.MenuItem.with_mnemonic ("_" + _("Project"));
        item_project.set_sensitive (false);
        add_menu (item_project);

        /* Help */
        var item_help = new Gtk.MenuItem.with_mnemonic ("_" + _("Help"));
        add_menu (item_help);

        var menu_help = new Gtk.Menu();
        item_help.set_submenu (menu_help);

        var item_about = new ImageMenuItem.from_stock (Stock.ABOUT, null);
        menu_help.append (item_about);
        item_about.activate.connect (ui_about_dialog);
    }

    void build_toolbar() {
        var btnNewFile = new ToolButton.from_stock (Stock.NEW);
        add_button (btnNewFile);
        btnNewFile.set_tooltip_text (_("Create new file"));
        btnNewFile.clicked.connect (create_new_file);

        var btnLoadProject = new ToolButton.from_stock (Stock.OPEN);
        add_button (btnLoadProject);
        btnLoadProject.set_tooltip_text (_("Open project"));
        btnLoadProject.clicked.connect (() => {
            ui_load_project (ui_elements_pool);
        });

        var btnSave = new ToolButton.from_stock (Stock.SAVE);
        add_button (btnSave);
        btnSave.set_tooltip_text (_("Save current file"));
        btnSave.clicked.connect (() => {
            project.buffer_save();
        });
        project.buffer_changed.connect (btnSave.set_sensitive);

        add_button (new SeparatorToolItem());

        var btnUndo = new ToolButton.from_stock (Stock.UNDO);
        btnUndo.set_sensitive (false);
        add_button (btnUndo);
        btnUndo.set_tooltip_text (_("Undo last change"));
        btnUndo.clicked.connect (undo_change);
        project.undo_changed.connect (btnUndo.set_sensitive);

        var btnRedo = new ToolButton.from_stock (Stock.REDO);
        btnRedo.set_sensitive (false);
        add_button (btnRedo);
        btnRedo.set_tooltip_text (_("Redo last change"));
        btnRedo.clicked.connect (redo_change);
        project.redo_changed.connect (btnRedo.set_sensitive);

        add_button (new SeparatorToolItem());

        var target_selector = new ComboBoxText();
        target_selector.set_tooltip_text (_("IDE mode"));
        var ti = new ToolItem();
        ti.add (target_selector);
        target_selector.append_text (_("Debug"));
        target_selector.append_text (_("Release"));
        target_selector.active = 0;
        target_selector.changed.connect (() => {
            project.idemode = (IdeModes) target_selector.active;
        });
        add_button (ti);

        var btnBuild = new Gtk.ToolButton.from_stock (Stock.EXECUTE);
        add_button (btnBuild);
        btnBuild.set_tooltip_text (_("Save current file and build project"));
        btnBuild.clicked.connect (() => {
            build_output.clear();
            switch (project.idemode) {
                case IdeModes.RELEASE:
                    project_builder.build_project();
                    break;
                case IdeModes.DEBUG:
                    project_builder.build_project (frankenstein);
                    break;
                default:
                    bug_msg (_("Unknown IDE mode: %s\n"), project.idemode.to_string());
                    break;
            }
        });

        var btnRun = new Gtk.ToolButton.from_stock (Stock.MEDIA_PLAY);
        add_button (btnRun);
        btnRun.set_tooltip_text (_("Run application"));
        btnRun.clicked.connect (() => {
            if (project_builder.app_running)
                project_builder.quit();
            else
                project_builder.launch();
        });
        project_builder.app_state_changed.connect ((running) => {
            if (running)
                btnRun.stock_id = Stock.MEDIA_STOP;
            else
                btnRun.stock_id = Stock.MEDIA_PLAY;
        });

        add_button (new SeparatorToolItem());

        var btnSettings = new Gtk.ToolButton.from_stock (Stock.PREFERENCES);
        add_button (btnSettings);
        btnSettings.set_tooltip_text (_("Settings"));
        btnSettings.clicked.connect (() => {
            ui_project_dialog (project);
        });
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
