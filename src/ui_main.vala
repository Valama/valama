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
static ProjectBrowser wdg_pbrw;
static UiReport wdg_report;
static ProjectBuilder project_builder;
static UiSourceViewer source_viewer;
static BuildOutput wdg_build_output;
static AppOutput wdg_app_output;
static UiCurrentFileStructure wdg_current_file_structure;
static UiBreakpoints wdg_breakpoints;
static UiSearch wdg_search;
static SymbolBrowser wdg_smb_browser;
static UiStyleChecker wdg_stylechecker;
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
     * Initialize Ui elements, menu and toolbar.
     */
    public void init() {
        source_viewer = new UiSourceViewer();
        source_viewer.add_srcitem (project.open_new_buffer ("", "", true));

        wdg_pbrw = new ProjectBrowser (project);
        wdg_pbrw.file_selected.connect ((filename) => {
            on_file_selected(filename);
        });

        wdg_smb_browser = new SymbolBrowser();
        wdg_pbrw.connect (wdg_smb_browser);

        var report_wrapper = new ReportWrapper();
        project.guanako_project.set_report_wrapper (report_wrapper);
        wdg_report = new UiReport (report_wrapper);

        frankenstein = new Guanako.FrankenStein();
        wdg_breakpoints = new UiBreakpoints (frankenstein);

        project_builder = new ProjectBuilder (project);
        wdg_build_output = new BuildOutput();
        wdg_app_output = new AppOutput();
        wdg_current_file_structure = new UiCurrentFileStructure();
        wdg_search = new UiSearch();
        wdg_stylechecker = new UiStyleChecker();

        /* Gdl elements. */
        add_item ("SourceView", _("Source view"), source_viewer,
                              null,
                              DockItemBehavior.NO_GRIP | DockItemBehavior.CANT_DOCK_CENTER,
                              DockPlacement.TOP);
        add_item ("ReportWrapper", _("Report widget"), wdg_report,
                              Stock.INFO,
                              DockItemBehavior.NORMAL,
                              DockPlacement.BOTTOM);
        add_item ("ProjectBrowser", _("Project browser"), wdg_pbrw,
                              Stock.FILE,
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("BuildOutput", _("Build output"), wdg_build_output,
                              Stock.FILE,
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("AppOutput", _("App output"), wdg_app_output,
                              Stock.FILE,
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("Search", _("Search"), wdg_search,
                              Stock.FIND,
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("Breakpoints", _("Breakpoints / Timers"), wdg_breakpoints,
                              Stock.FILE,
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("CurrentFileStructure", _("Current file"), wdg_current_file_structure,
                              Stock.FILE,
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("StyleChecker", _("Coding style checker"), wdg_stylechecker,
                              Stock.COLOR_PICKER,
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("SymbolBrowser", _("Symbol browser"), wdg_smb_browser,
                              Stock.CONVERT,
                              DockItemBehavior.NORMAL,
                              DockPlacement.RIGHT);

        /* Keep this before layout loading. */
        dock.show_all();

        /* Load default layout. Either local one or system wide. */
        bool err = false;
        string local_layout_filename;
        if (Args.layoutfile == null)
            local_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                     Environment.get_user_cache_dir(),
                                                     "valama",
                                                     "layout.xml");
        else {
            local_layout_filename = Args.layoutfile;
            err = true;
        }
        string system_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                         Config.PACKAGE_DATA_DIR,
                                                         "layout.xml");
        if (Args.reset_layout || (!load_layout (local_layout_filename, null, err) &&
                                                                Args.layoutfile == null))
            load_layout (system_layout_filename);

        /* Keep this after layout loading. */
        build_toolbar();
        build_menu();

        show();
    }

    /**
     * Save gdl layout.
     */
    private void on_destroy() {
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
     * Build up menu.
     */
    private void build_menu() {
        /* File */
        var item_file = new Gtk.MenuItem.with_mnemonic ("_" + _("File"));
        add_menu (item_file);
        var menu_file = new Gtk.Menu();
        item_file.set_submenu (menu_file);

        var item_file_new = new ImageMenuItem.from_stock (Stock.NEW, null);
        menu_file.append (item_file_new);
        item_file_new.activate.connect (create_new_file);
        add_accel_activate (item_file_new, Gdk.Key.n);

        var item_file_open = new ImageMenuItem.from_stock (Stock.OPEN, null);
        menu_file.append (item_file_open);
        item_file_open.activate.connect (() => {
            ui_load_project();
        });
        add_accel_activate (item_file_open, Gdk.Key.o);

        var item_file_save = new ImageMenuItem.from_stock (Stock.SAVE, null);
        menu_file.append (item_file_save);
        item_file_save.activate.connect (() => {
            project.buffer_save();
        });
        project.buffer_changed.connect (item_file_save.set_sensitive);
        add_accel_activate (item_file_save, Gdk.Key.s);

        menu_file.append (new SeparatorMenuItem());

        var item_file_quit = new ImageMenuItem.from_stock (Stock.QUIT, null);
        menu_file.append (item_file_quit);
        item_file_quit.activate.connect (() => {
            on_destroy();
            main_quit();
        });
        add_accel_activate (item_file_quit, Gdk.Key.q);

        /* Edit */
        var item_edit = new Gtk.MenuItem.with_mnemonic ("_" + _("Edit"));
        add_menu (item_edit);
        var menu_edit = new Gtk.Menu();
        item_edit.set_submenu (menu_edit);

        var item_edit_undo = new ImageMenuItem.from_stock (Stock.UNDO, null);
        item_edit_undo.set_sensitive (false);
        menu_edit.append (item_edit_undo);
        item_edit_undo.activate.connect (undo_change);
        project.undo_changed.connect (item_edit_undo.set_sensitive);
        add_accel_activate (item_edit_undo, Gdk.Key.u);

        var item_edit_redo = new ImageMenuItem.from_stock (Stock.REDO, null);
        item_edit_redo.set_sensitive (false);
        menu_edit.append (item_edit_redo);
        item_edit_redo.activate.connect (redo_change);
        project.redo_changed.connect (item_edit_redo.set_sensitive);
        add_accel_activate (item_edit_redo, Gdk.Key.r);

        /* View */
        var item_view = new Gtk.MenuItem.with_mnemonic ("_" + _("View"));
        add_menu (item_view);
        var menu_view = new Gtk.Menu();
        item_view.set_submenu (menu_view);

        add_view_menu_item (menu_view, wdg_search, _("Show search"), true, Gdk.Key.f);
        add_view_menu_item (menu_view, wdg_report, _("Show reports"));
        add_view_menu_item (menu_view, wdg_pbrw, _("Show project browser"));
        add_view_menu_item (menu_view, wdg_build_output, _("Show build output"));
        add_view_menu_item (menu_view, wdg_app_output, _("Show application output"));
        add_view_menu_item (menu_view, wdg_breakpoints, _("Show breakpoints"));
        add_view_menu_item (menu_view, wdg_current_file_structure, _("Show current file structure"));
        add_view_menu_item (menu_view, wdg_stylechecker, _("Show stylechecker"));
        add_view_menu_item (menu_view, wdg_smb_browser, _("Show symbol browser"));

        var item_view_lockhide = new CheckMenuItem.with_mnemonic ("_" + _("Lock elements"));
        menu_view.append (item_view_lockhide);
        item_view_lockhide.toggled.connect (() => {
            if (item_view_lockhide.active)
                lock_items();
            else
                unlock_items();
        });
        this.lock_items.connect (() => {
            item_view_lockhide.active = true;
        });
        this.unlock_items.connect (() => {
            item_view_lockhide.active = false;
        });
        add_accel_activate (item_view_lockhide, Gdk.Key.h);

        /* Project */
        var item_project = new Gtk.MenuItem.with_mnemonic ("_" + _("Project"));
        item_project.set_sensitive (false);
        add_menu (item_project);
        var menu_project = new Gtk.Menu();
        item_project.set_submenu (menu_project);

        /* Help */
        var item_help = new Gtk.MenuItem.with_mnemonic ("_" + _("Help"));
        add_menu (item_help);
        var menu_help = new Gtk.Menu();
        item_help.set_submenu (menu_help);

        var item_help_about = new ImageMenuItem.from_stock (Stock.ABOUT, null);
        menu_help.append (item_help_about);
        item_help_about.activate.connect (ui_about_dialog);

        this.menubar.show_all();
    }

    /**
     * Build up toolbar.
     */
    private void build_toolbar() {
        var btnReturn = new ToolButton (new Image.from_icon_name ("go-previous-symbolic", IconSize.BUTTON), _("Back"));
        add_button (btnReturn);
        btnReturn.set_tooltip_text (_("Close project"));
        btnReturn.clicked.connect (() => {
            request_close();
        });

        add_button (new SeparatorToolItem());

        var btnNewFile = new ToolButton.from_stock (Stock.NEW);
        add_button (btnNewFile);
        btnNewFile.set_tooltip_text (_("Create new file"));
        btnNewFile.clicked.connect (create_new_file);

        /*var btnLoadProject = new ToolButton.from_stock (Stock.OPEN);
        add_button (btnLoadProject);
        btnLoadProject.set_tooltip_text (_("Open project"));
        btnLoadProject.clicked.connect (() => {
            ui_load_project();
        });*/

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
        foreach (var mode in IdeModes.values())
            target_selector.append_text (mode.to_string());
        target_selector.changed.connect (() => {
            project.idemode = IdeModes.int_to_mode (target_selector.active);
        });
        /* Make sure the idemode signal will be emitted. */
        target_selector.active = IdeModes.to_int (project.idemode);
        add_button (ti);

        var btnBuild = new Gtk.ToolButton.from_stock (Stock.EXECUTE);
        add_accel_activate (btnBuild, Gdk.Key.b, Gdk.ModifierType.CONTROL_MASK, "clicked");
        add_button (btnBuild);
        btnBuild.set_tooltip_text (_("Save current file and build project"));
        btnBuild.clicked.connect (() => {
            project_builder.build_project();
        });

        var btnRun = new Gtk.ToolButton.from_stock (Stock.MEDIA_PLAY);
        add_accel_activate (btnRun, Gdk.Key.l, Gdk.ModifierType.CONTROL_MASK, "clicked");
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

        var separator_expand = new SeparatorToolItem();
        separator_expand.set_expand (true);
        separator_expand.draw = false;
        add_button (separator_expand);

        add_view_toolbar_item (toolbar, wdg_search, null, "edit-find-symbolic");

        var btn_lock = new ToggleToolButton();
        btn_lock.icon_name = "changes-prevent-symbolic";
        btn_lock.toggled.connect (() => {
            if (btn_lock.active)
                lock_items();
            else
                unlock_items();
        });
        this.lock_items.connect (() => {
            btn_lock.active = true;
        });
        this.unlock_items.connect (() => {
            btn_lock.active = false;
        });
        toolbar.add (btn_lock);

        toolbar.show_all();
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
#if GDL_3_6_2 && VALAC_0_20
        item_view_element.active = !element.dock_item.is_closed();
#elif !GDL_3_6_2
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
    public void add_view_toolbar_item (Toolbar toolbar,
                                       UiElement element,
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

#if GDL_3_6_2 && VALAC_0_20
        btn_element.active = !element.dock_item.is_closed();
#elif !GDL_3_6_2
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
