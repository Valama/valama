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
using Xml;

static ValamaProject project;
static Guanako.FrankenStein frankenstein;

static bool parsing = false;

//TODO: Use plugins.
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
static UiStructureView wdg_structure_view;
static GladeViewer wdg_glade_viewer;
static UiValadocBrowser wdg_valadoc_browser;
// static UiStyleChecker wdg_stylechecker;

static Gee.HashMap<string, Gdk.Pixbuf> map_icons;


/**
 * Main window class. Setup {@link Gdl.Dock} and {@link Gdl.DockBar} stuff.
 */
public class MainWidget : Box {
    /**
     * Master dock for all items except {@link toolbar} and {@link menu}.
     */
    private Dock dock;
    /**
     * Layout of master dock {@link dock}.
     */
    private DockLayout layout;
    /**
     * View settings menu.
     */
    private Gtk.Menu viewmenu;
    /**
     * Settings menu.
     */
    private Gtk.Menu menu;
    /**
     * View settings menu button.
     */
    public MenuButton views { get; private set; }
    /**
     * Settings menu button.
     */
    public MenuButton settings { get; private set; }
    /**
     * Toolbar. Fill with {@link add_button}.
     */
    private Toolbar toolbar_left;
    /**
     * Toolbar. Fill with {@link add_button}.
     */
    private Toolbar toolbar_right;
    /**
     * Toolbar container on left side of window title.
     */
    public Box tbox_left { get; private set; }
    /**
     * Toolbar container on right side of window title.
     */
    public Box tbox_right { get; private set; }

    private ToggleButton fullsc_tbut;

    /**
     * Global shortcut object.
     */
    public AccelGroup accel_group;

    /**
     * Emit when widget can be closed.
     */
    public signal void request_close();

    /**
     * Internal state of items if {@link Gdl.DockItemGrip} is to be shown.
     */
    private bool locked = false;
    /**
     * Emit to hide dock item grip (if not disabled).
     */
    public virtual signal void lock_items() {
        locked = true;
    }
    /**
     * Emit to show dock item grip.
     */
    public virtual signal void unlock_items() {
        locked = false;
    }

    /**
     * Emit when all {@link UiElement}s, menu objects and tool objects are
     * initialized.
     */
    public signal void initialized();

    /**
     * Create MainWindow. Initialize {@link menu}, toolbars, master dock and
     * source dock.
     */
    public MainWidget() {
        accel_group = new AccelGroup();

        this.orientation = Orientation.VERTICAL;
        this.spacing = 0;

        /* Menus. */
        this.menu = new Gtk.Menu();
        this.viewmenu = new Gtk.Menu();

        /* Setting buttons. */
        this.views = new MenuButton();
        this.views.set_tooltip_text (_("Views"));
        this.views.popup = this.viewmenu;
        this.views.show_all();
        this.settings = new MenuButton();
        this.settings.image = new Image.from_icon_name ("emblem-system-symbolic", IconSize.BUTTON);
        this.settings.set_tooltip_text (_("Settings"));
        this.settings.popup = this.menu;
        this.settings.show_all();

        /* Toolbars. */
        this.toolbar_left = new Toolbar();
        var toolbar_left_scon = toolbar_left.get_style_context();
        toolbar_left_scon.add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
        this.toolbar_right = new Toolbar();
        var toolbar_right_scon = toolbar_right.get_style_context();
        toolbar_right_scon.add_class (STYLE_CLASS_PRIMARY_TOOLBAR);

        /* Toolbar containers */
        this.tbox_left = new Box (Orientation.HORIZONTAL, 0);
        this.tbox_left.pack_start (this.toolbar_left);
        this.tbox_left.show_all();
        this.tbox_right = new Box (Orientation.HORIZONTAL, 0);
        this.tbox_right.pack_start (this.toolbar_right);
        this.tbox_right.show_all();

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
     * Initialize ui_elements, menu and toolbars.
     */
    public void init() {
        source_viewer = new UiSourceViewer();
        source_viewer.add_srcitem (project.open_new_buffer ("", "", true));

        wdg_pbrw = new ProjectBrowser (project);
        wdg_pbrw.file_selected.connect ((filename) => {
            on_file_selected(filename);
        });


        project.guanako_project.set_reporter (typeof (ReportWrapper));

        frankenstein = new Guanako.FrankenStein();

        wdg_report = new UiReport();
        wdg_smb_browser = new SymbolBrowser();
        project_builder = new ProjectBuilder();
        wdg_breakpoints = new UiBreakpoints (frankenstein);
        wdg_build_output = new BuildOutput();
        wdg_app_output = new AppOutput();
        wdg_current_file_structure = new UiCurrentFileStructure();
        wdg_search = new UiSearch();
        wdg_structure_view = new UiStructureView();
        wdg_glade_viewer = new GladeViewer();
        wdg_valadoc_browser = new UiValadocBrowser();
        // wdg_stylechecker = new UiStyleChecker();

        /* Gdl elements. */
        add_item ("SourceView", _("Source view"), source_viewer,
                              null,
                              DockItemBehavior.NO_GRIP | DockItemBehavior.CANT_DOCK_CENTER,
                              DockPlacement.TOP);
        add_item ("ReportWrapper", _("Report widget"), wdg_report,
                              "gtk-info",
                              DockItemBehavior.NORMAL,
                              DockPlacement.BOTTOM);
        add_item ("ProjectBrowser", _("Project browser"), wdg_pbrw,
                              "gtk-file",
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("BuildOutput", _("Build output"), wdg_build_output,
                              "gtk-file",
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("AppOutput", _("Application output"), wdg_app_output,
                              "gtk-file",
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("Search", _("Search"), wdg_search,
                              "gtk-find",
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("Breakpoints", _("Breakpoints / Timers"), wdg_breakpoints,
                              "gtk-file",
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        add_item ("CurrentFileStructure", _("Current file"), wdg_current_file_structure,
                              "gtk-file",
                              DockItemBehavior.NORMAL,
                              DockPlacement.LEFT);
        // add_item ("StyleChecker", _("Coding style checker"), wdg_stylechecker,
        //                       "gtk-color-picker",
        //                       DockItemBehavior.NORMAL,
        //                       DockPlacement.LEFT);
        add_item ("SymbolBrowser", _("Symbol browser"), wdg_smb_browser,
                              "gtk-convert",
                              DockItemBehavior.NORMAL,
                              DockPlacement.RIGHT);
        add_item ("StructureView", _("Structure view"), wdg_structure_view,
                              "gtk-file",
                              DockItemBehavior.NORMAL,
                              DockPlacement.RIGHT);
        add_item ("GladeViewer", _("Glade viewer"), wdg_glade_viewer,
                              "gtk-file",
                              DockItemBehavior.NORMAL,
                              DockPlacement.RIGHT);
        add_item ("ValadocBrowser", _("Valadoc browser"), wdg_valadoc_browser,
                              "gtk-file",
                              DockItemBehavior.NORMAL,
                              DockPlacement.RIGHT);

        /* Keep this before layout loading. */
        dock.show_all();

        /* Load default layout. Either local one or system wide. */
        var err = false;
        string local_layout_filename;
        var cachedir = Path.build_path (Path.DIR_SEPARATOR_S,
                                        Environment.get_user_cache_dir(),
                                        "valama");
        if (Args.layoutfile == null)
            local_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                     cachedir,
                                                     "layout.xml");
        else {
            local_layout_filename = Args.layoutfile;
            err = true;
        }
        var system_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                      Config.PACKAGE_DATA_DIR,
                                                      "layout.xml");
        if (Args.reset_layout || (!load_layout (this.layout,
                                                local_layout_filename,
                                                null,
                                                err) && Args.layoutfile == null))
            load_layout (this.layout, system_layout_filename);

        try {
            load_meta (Path.build_path (Path.DIR_SEPARATOR_S,
                                        cachedir,
                                        "ui_meta.xml"));
        } catch (LoadingError e) {
            warning_msg (_("Could not load meta information: %s\n"), e.message);
        }

        /* Keep this after layout loading. */
        build_menu();
        build_toolbars();

        if (locked)
            lock_items();

        show();
        initialized();
    }

    /**
     * Save gdl layout.
     */
    public bool close() {
        project_builder.quit();

        var cachedir = Path.build_path (Path.DIR_SEPARATOR_S,
                                        Environment.get_user_cache_dir(),
                                        "valama");
        /* Meta info. */
        save_meta (Path.build_path (Path.DIR_SEPARATOR_S,
                                    cachedir,
                                    "ui_meta.xml"));

        /* Gdl main layout. */
        var local_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                     cachedir,
                                                     "layout.xml");
        var f = File.new_for_path (local_layout_filename).get_parent();
        if (!f.query_exists())
            try {
                f.make_directory_with_parents();
            } catch (GLib.Error e) {
                errmsg (_("Could not create cache directory: %s\n"), e.message);
            }
        save_layout (this.layout, local_layout_filename);
        return true;
    }

    /**
     * Build up menu.
     */
    private void build_menu() {
        /* File */
        var item_file_new = new ImageMenuItem.with_mnemonic (_("_New"));
        var image_file_new = new Image();
        image_file_new.icon_name = "document-new";
        item_file_new.image = image_file_new;
        this.menu.append (item_file_new);
        item_file_new.activate.connect (create_new_file);
        add_accel_activate (item_file_new, Gdk.Key.n);

        var item_file_save = new ImageMenuItem.with_mnemonic (_("_Save all"));
        var image_file_save = new Image();
        image_file_save.icon_name = "document-save";
        item_file_save.image = image_file_save;
        this.menu.append (item_file_save);
        item_file_save.activate.connect (() => {
            project.buffer_save();
        });
        project.buffer_changed.connect (item_file_save.set_sensitive);
        add_accel_activate (item_file_save, Gdk.Key.s);

        this.menu.append (new SeparatorMenuItem());

        /* Edit */
        var item_edit_undo = new ImageMenuItem.with_mnemonic (_("_Undo"));
        var image_edit_undo = new Image();
        image_edit_undo.icon_name = "edit-undo";
        item_edit_undo.image = image_edit_undo;
        item_edit_undo.set_sensitive (false);
        this.menu.append (item_edit_undo);
        item_edit_undo.activate.connect (undo_change);
        project.undo_changed.connect (item_edit_undo.set_sensitive);
        add_accel_activate (item_edit_undo, Gdk.Key.u);

        var item_edit_redo = new ImageMenuItem.with_mnemonic (_("_Redo"));
        var image_edit_redo = new Image();
        image_edit_redo.icon_name = "edit-redo";
        item_edit_redo.image = image_edit_redo;
        item_edit_redo.set_sensitive (false);
        this.menu.append (item_edit_redo);
        item_edit_redo.activate.connect (redo_change);
        project.redo_changed.connect (item_edit_redo.set_sensitive);
        add_accel_activate (item_edit_redo, Gdk.Key.r);

        var item_edit_search = new ImageMenuItem.with_mnemonic (_("_Search"));
        var image_edit_search = new Image();
        image_edit_search.icon_name = "edit-search";
        item_edit_search.image = image_edit_search;
        item_edit_search.set_sensitive (true);
        this.menu.append (item_edit_search);
        item_edit_search.activate.connect (wdg_search.search_for_current_selection);
        add_accel_activate (item_edit_search, Gdk.Key.f);

        this.menu.append (new SeparatorMenuItem());

        /* View */
        add_view_menu_item (wdg_search, _("Show search"));
        add_view_menu_item (wdg_report, _("Show reports"));
        add_view_menu_item (wdg_pbrw, _("Show project browser"));
        add_view_menu_item (wdg_build_output, _("Show build output"));
        add_view_menu_item (wdg_app_output, _("Show application output"));
        add_view_menu_item (wdg_breakpoints, _("Show breakpoints"));
        add_view_menu_item (wdg_current_file_structure, _("Show current file structure"));
        // add_view_menu_item (wdg_stylechecker, _("Show style checker"));
        add_view_menu_item (wdg_smb_browser, _("Show symbol browser"));
        add_view_menu_item (wdg_glade_viewer, _("Show glade viewer"));
        add_view_menu_item (wdg_structure_view, _("Show structure viewer"));
        add_view_menu_item (wdg_valadoc_browser, _("Show Valadoc browser"));
        this.viewmenu.append (new SeparatorMenuItem());

        // TRANSLATORS: Lock user interface elements to prevent moving them around.
        var item_view_lockhide = new CheckMenuItem.with_mnemonic (_("_Lock elements"));
        this.viewmenu.append (item_view_lockhide);
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

        var item_view_fullscreen = new CheckMenuItem.with_mnemonic (_("_Fullscreen"));
        this.viewmenu.append (item_view_fullscreen);
        item_view_fullscreen.toggled.connect (() => {
            if (item_view_fullscreen.active) {
                if (!fullsc_tbut.active)
                    fullsc_tbut.active = true;
            } else {
                if (fullsc_tbut.active)
                    fullsc_tbut.active = false;
            }
        });
        /**
         * FIXME: Use hidden button to get out of fullscreen mode via
         *        keybinding. Menu item doesn't work when header bar is
         *        hidden.
         */
        fullsc_tbut = new ToggleButton();
        fullsc_tbut.toggled.connect (() => {
            if (fullsc_tbut.active) {
                if (!item_view_fullscreen.active)
                    item_view_fullscreen.active = true;
                window_main.fullscreen();
            } else {
                if (item_view_fullscreen.active)
                    item_view_fullscreen.active = false;
                window_main.unfullscreen();
            }
        });
        this.add (fullsc_tbut);
        fullsc_tbut.show_all();
        add_accel_activate (fullsc_tbut, Gdk.Key.F11, 0);

        /* Project */
        var item_project_settings = new ImageMenuItem.with_mnemonic (_("Project _settings"));
        var image_project_settings = new Image();
        image_project_settings.icon_name = "preferences-system";
        item_project_settings.image = image_project_settings;
        this.menu.append (item_project_settings);
        item_project_settings.activate.connect (() => {
            ui_project_dialog (project);
        });

        this.menu.append (new SeparatorMenuItem());

        /* Build */
        var item_build = new Gtk.MenuItem.with_mnemonic (_("_Build"));
        this.menu.add (item_build);
        item_build.set_submenu (build_build_menu());

        this.menu.append (new SeparatorMenuItem());

        /* Run */
        var item_run_run = new ImageMenuItem.with_mnemonic (_("_Execute"));
        var image_run_run = new Image();
        image_run_run.icon_name = "media-playback-start";
        item_run_run.image = image_run_run;
        add_accel_activate (item_run_run, Gdk.Key.F5, 0);
        this.menu.append (item_run_run);
        item_run_run.activate.connect (() => {
            project_builder.launch();
        });

        var item_run_stop = new ImageMenuItem.with_mnemonic (_("_Stop"));
        var image_run_stop = new Image();
        image_run_stop.icon_name = "media-playback-stop";
        item_run_stop.image = image_run_stop;
        item_run_stop.sensitive = false;
        add_accel_activate (item_run_run, Gdk.Key.F5, Gdk.ModifierType.SHIFT_MASK);
        this.menu.append (item_run_stop);
        item_run_stop.activate.connect (() => {
            project_builder.quit();
        });
        project_builder.notify["app-running"].connect (() => {
            if (project_builder.app_running) {
                item_run_run.sensitive = false;
                item_run_stop.sensitive = true;
            } else {
                item_run_run.sensitive = true;
                item_run_stop.sensitive = false;
            }
        });

        this.menu.append (new SeparatorMenuItem());

        /* Help */
        var item_help_about = new ImageMenuItem.with_mnemonic (_("_About"));
        var image_help_about = new Image();
        image_help_about.icon_name = "help-about";
        item_help_about.image = image_help_about;
        this.menu.append (item_help_about);
        item_help_about.activate.connect (ui_about_dialog);

        /* Quit */
        var item_file_quit = new ImageMenuItem.with_mnemonic (_("_Quit"));
        var image_file_quit = new Image();
        image_file_quit.icon_name = "application-exit";
        item_file_quit.image = image_file_quit;
        this.menu.append (item_file_quit);
        item_file_quit.activate.connect (() => {
            quit_valama();
        });
        add_accel_activate (item_file_quit, Gdk.Key.q);

        this.viewmenu.show_all();
        this.menu.show_all();
    }

    private Gtk.Menu build_build_menu () {
        var menu_build = new Gtk.Menu();

        var item_build_build = new ImageMenuItem.with_mnemonic (_("_Build"));
        var image_build_build = new Image();
        image_build_build.icon_name = "system-run";
        item_build_build.image = image_build_build;
        add_accel_activate (item_build_build, Gdk.Key.F7, 0);
        menu_build.append (item_build_build);
        item_build_build.activate.connect (() => {
            project_builder.build_project();
        });

        var item_build_rebuild = new ImageMenuItem.with_label (_("Rebuild"));
        menu_build.append (item_build_rebuild);
        item_build_rebuild.activate.connect (() => {
            project_builder.build_project (true);
        });

        var item_build_cleanbuild = new ImageMenuItem.with_label (_("Clean build"));
        menu_build.append (item_build_cleanbuild);
        item_build_cleanbuild.activate.connect (() => {
            project_builder.build_project (false, false, true);
        });

        var item_build_clean = new ImageMenuItem.with_mnemonic (_("_Clean"));
        var image_build_clean = new Image();
        image_build_clean.icon_name = "edit-clear";
        item_build_clean.image = image_build_clean;
        menu_build.append (item_build_clean);
        item_build_clean.activate.connect (() => {
            project_builder.clean_project();
        });

        var item_build_distclean = new ImageMenuItem.with_label (_("Clean all"));
        menu_build.append (item_build_distclean);
        item_build_distclean.activate.connect (() => {
            project_builder.distclean_project();
        });
        menu_build.show_all();
        return menu_build;
    }

    /**
     * Build up toolbars.
     */
    private void build_toolbars() {
        var btnReturn = new ToolButton (new Image.from_icon_name ("go-previous-symbolic", IconSize.BUTTON), _("Back"));
        toolbar_left.add (btnReturn);
        btnReturn.set_tooltip_text (_("Close project"));
        btnReturn.clicked.connect (() => {
            if (project.close())
                request_close();
        });

        toolbar_left.add (new SeparatorToolItem());

        var btnNewFile = new ToolButton (null, _("New"));
        btnNewFile.icon_name = "document-new";
        toolbar_left.add (btnNewFile);
        btnNewFile.set_tooltip_text (_("Create new file"));
        btnNewFile.clicked.connect (create_new_file);

        var btnSave = new ToolButton (null, _("Save"));
        btnSave.icon_name = "document-save";
        toolbar_left.add (btnSave);
        btnSave.set_tooltip_text (_("Save current file"));
        btnSave.clicked.connect (() => {
            project.buffer_save();
        });
        project.buffer_changed.connect (btnSave.set_sensitive);

        toolbar_left.add (new SeparatorToolItem());

        var btnUndo = new ToolButton (null, _("Undo"));
        btnUndo.icon_name = "edit-undo";
        btnUndo.set_sensitive (false);
        toolbar_left.add (btnUndo);
        btnUndo.set_tooltip_text (_("Undo last change"));
        btnUndo.clicked.connect (undo_change);
        project.undo_changed.connect (btnUndo.set_sensitive);

        var btnRedo = new ToolButton (null, _("Redo"));
        btnRedo.icon_name = "edit-redo";
        btnRedo.set_sensitive (false);
        toolbar_left.add (btnRedo);
        btnRedo.set_tooltip_text (_("Redo last change"));
        btnRedo.clicked.connect (redo_change);
        project.redo_changed.connect (btnRedo.set_sensitive);

        toolbar_left.add (new SeparatorToolItem());

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
        toolbar_left.add (ti);

        var btnBuild = new Gtk.MenuToolButton (null, _("Build"));
        btnBuild.icon_name = "system-run";
        btnBuild.set_menu (build_build_menu());
        toolbar_left.add (btnBuild);
        btnBuild.set_tooltip_text (_("Save current file and build project"));
        btnBuild.clicked.connect (() => {
            project_builder.build_project();
        });

        var btnRun = new Gtk.ToolButton (null, _("Execute"));
        btnRun.icon_name = "media-playback-start";
        toolbar_left.add (btnRun);
        btnRun.set_tooltip_text (_("Run application"));
        btnRun.clicked.connect (() => {
            if (project_builder.app_running)
                project_builder.quit();
            else
                project_builder.launch();
        });
        project_builder.notify["app-running"].connect (() => {
            btnRun.icon_name = (project_builder.app_running) ? "media-playback-stop"
                                                             : "media-playback-start";
        });

        add_view_toolbar_item (toolbar_right, wdg_search, "edit-find-symbolic");

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
        toolbar_right.add (btn_lock);

        toolbar_left.show_all();
        toolbar_right.show_all();
    }

    /**
     * Add new item to master dock {@link dock}.
     *
     * @param item_name Unique name of new {@link Gdl.DockItem}.
     * @param item_long_name Display name of new {@link Gdl.DockItem}.
     * @param element {@link UiElement} to add {@link UiElement.widget} to
     *                new {@link Gdl.DockItem}.
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
     * @param element {@link UiElement} to connect toggle signals with.
     * @param label Description to show in menu.
     * @param with_mnemonic If `true` enable mnemonic.
     * @param key Accelerator {@link Gdk.Key} or null if none.
     * @param modtype Modifier type e.g. {@link Gdk.ModifierType.CONTROL_MASK} for ctrl.
     */
    public void add_view_menu_item (UiElement element,
                                    string label,
                                    bool with_mnemonic = false,
                                    int? key = null,
                                    Gdk.ModifierType modtype = Gdk.ModifierType.CONTROL_MASK) {
        CheckMenuItem item_view_element;
        if (with_mnemonic)
            item_view_element = new CheckMenuItem.with_mnemonic (@"_$label");
        else
            item_view_element = new CheckMenuItem.with_label (label);
        item_view_element.active = !element.dock_item.is_closed();
        this.viewmenu.append (item_view_element);

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
     * @param icon_name Icon from theme.
     */
    public void add_view_toolbar_item (Toolbar toolbar,
                                       UiElement element,
                                       string icon_name) {
        var btn_element = new ToggleToolButton();
        btn_element.icon_name = icon_name;
        toolbar.add (btn_element);

        btn_element.active = !element.dock_item.is_closed();
        btn_element.toggled.connect (() => {
            element.show_element (btn_element.active);
        });
        element.show_element.connect ((show) => {
            if (show != btn_element.active)
                btn_element.active = show;
        });
    }

    //TODO; Move this to layout file.
    /**
     * Save user interface meta information.
     *
     * @param path File path to save to.
     */
    private void save_meta (string path) {
        debug_msg (_("Save Ui meta information: %s\n"), path);
        var writer = new TextWriter.filename (path);
        writer.set_indent (true);
        writer.set_indent_string ("    ");

        //TODO: Meta file version.
        writer.start_element ("ui-meta");
        //writer.write_attribute ("version", xXx);
        writer.write_element ("locked", (locked) ? "true" : "false");
        writer.end_element();
    }

    /**
     * Load meta information.
     *
     * @param path File path to load from.
     */
    private void load_meta (string path) throws LoadingError {
        debug_msg (_("Load Ui meta information: %s\n"), path);

        Xml.Doc* doc = Xml.Parser.parse_file (path);

        if (doc == null) {
            delete doc;
            throw new LoadingError.FILE_IS_GARBAGE (_("Cannot parse file."));
        }

        Xml.Node* root_node = doc->get_root_element();
        if (root_node == null || root_node->name != "ui-meta") {
            delete doc;
            throw new LoadingError.FILE_IS_EMPTY (_("File does not contain enough information."));
        }

        // if (root_node->has_prop ("version") != null)
        //     xXx = root_node->get_prop ("version");
        // if (comp_version (xXx, xXx_VERSION_MIN) < 0) {
        //     var errstr = _("Project file too old: %s < %s").printf (xXx,
        //                                                             xXx_VERSION_MIN);
        //     if (!Args.forceold) {
        //         throw new LoadingError.FILE_IS_OLD (errstr);
        //         delete doc;
        //     } else
        //         warning_msg (_("Ignore project file loading error: %s\n"), errstr);
        // }

        for (Xml.Node* i = root_node->children; i != null; i = i->next) {
            if (i->type != ElementType.ELEMENT_NODE)
                continue;
            switch (i->name) {
                case "locked":
                    switch (i->get_content()) {
                        case "true":
                            locked = true;
                            break;
                        case "false":
                            locked = false;
                            break;
                        default:
                            warning_msg (_("Unknown attribute for '%s' line %hu: %s\n"),
                                         "locked", i->line, i->get_content());
                            break;
                    }
                    break;
                default:
                    warning_msg (_("Unknown configuration file value line %hu: %s\n"),
                                 i->line, i->name);
                    break;
            }
        }
    }

    /**
     * Focus a {@link Gdl.DockItem}.
     *
     * @param item The item to receive focus.
     */
    public void focus_dock_item (DockItem item) {
        // TRANSLATORS:
        // Focus docking widget (Gdl.DockItem): long name / file name (short name)
        debug_msg (_("Focus dock item: %s (%s)\n"), item.long_name, item.name);
        /* Hack around gdl_dock_notebook with gtk_notebook. */
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
     * @param key {@link Gdk.Key} number to connect to signal (with modtype).
     * @param modtype {@link Gdk.ModifierType} to connect to signal together
     *                with key name. Default modifier key is "ctrl".
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
