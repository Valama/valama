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

static ValamaProject project;

//FIXME: Make them to plugins.
static ProjectBrowser wdg_pbrw;
static UiReport wdg_report;
static ProjectBuilder project_builder;
static UiSourceViewer source_viewer;
static BuildOutput wdg_build_output;
static AppOutput wdg_app_output;
static UiCurrentFileStructure wdg_current_file_structure;
static UiBreakpoints wdg_breakpoints;
static Guanako.FrankenStein frankenstein;
static UiSearch wdg_search;
static SymbolBrowser wdg_smb_browser;
static UiStyleChecker wdg_stylechecker;

static Gee.HashMap<string, Gdk.Pixbuf> map_icons;

/**
 * Initialize Ui elements, menu and toolbar.
 */
public void init_main_widget (MainWidget mwidget) {
    UiElement.project = project;

    source_viewer = new UiSourceViewer();
    source_viewer.add_srcitem (project.open_new_buffer ("", "", true));

    wdg_pbrw = new ProjectBrowser();
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
    mwidget.add_item ("SourceView", _("Source view"), source_viewer,
                          null,
                          DockItemBehavior.NO_GRIP | DockItemBehavior.CANT_DOCK_CENTER,
                          DockPlacement.TOP);
    mwidget.add_item ("ReportWrapper", _("Report widget"), wdg_report,
                          Stock.INFO,
                          DockItemBehavior.NORMAL,
                          DockPlacement.BOTTOM);
    mwidget.add_item ("ProjectBrowser", _("Project browser"), wdg_pbrw,
                          Stock.FILE,
                          DockItemBehavior.NORMAL,
                          DockPlacement.LEFT);
    mwidget.add_item ("BuildOutput", _("Build output"), wdg_build_output,
                          Stock.FILE,
                          DockItemBehavior.NORMAL,
                          DockPlacement.LEFT);
    mwidget.add_item ("AppOutput", _("App output"), wdg_app_output,
                          Stock.FILE,
                          DockItemBehavior.NORMAL,
                          DockPlacement.LEFT);
    mwidget.add_item ("Search", _("Search"), wdg_search,
                          Stock.FIND,
                          DockItemBehavior.NORMAL,
                          DockPlacement.LEFT);
    mwidget.add_item ("Breakpoints", _("Breakpoints / Timers"), wdg_breakpoints,
                          Stock.FILE,
                          DockItemBehavior.NORMAL,
                          DockPlacement.LEFT);
    mwidget.add_item ("CurrentFileStructure", _("Current file"), wdg_current_file_structure,
                          Stock.FILE,
                          DockItemBehavior.NORMAL,
                          DockPlacement.LEFT);
    mwidget.add_item ("StyleChecker", _("Coding style checker"), wdg_stylechecker,
                          Stock.COLOR_PICKER,
                          DockItemBehavior.NORMAL,
                          DockPlacement.LEFT);
    mwidget.add_item ("SymbolBrowser", _("Symbol browser"), wdg_smb_browser,
                          Stock.CONVERT,
                          DockItemBehavior.NORMAL,
                          DockPlacement.RIGHT);

    /* Keep this before layout loading. */
    mwidget.show_all();

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
    var system_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                  Config.PACKAGE_DATA_DIR,
                                                  "layout.xml");
    if (Args.reset_layout || (!mwidget.load_layout (local_layout_filename, null, err) &&
                                                            Args.layoutfile == null))
        mwidget.load_layout (system_layout_filename);

    /* Keep this after layout loading. */
    build_toolbar (mwidget);
    build_menu (mwidget);

    mwidget.show();
}


/**
 * Build up menu.
 */
private void build_menu (MainWidget mwidget) {
    /* File */
    var item_file = new Gtk.MenuItem.with_mnemonic ("_" + _("File"));
    mwidget.add_menu (item_file);
    var menu_file = new Gtk.Menu();
    item_file.set_submenu (menu_file);

    var item_file_new = new ImageMenuItem.from_stock (Stock.NEW, null);
    menu_file.append (item_file_new);
    item_file_new.activate.connect (create_new_file);
    mwidget.add_accel_activate (item_file_new, Gdk.Key.n);

    var item_file_open = new ImageMenuItem.from_stock (Stock.OPEN, null);
    menu_file.append (item_file_open);
    item_file_open.activate.connect (() => {
        ui_load_project();
    });
    mwidget.add_accel_activate (item_file_open, Gdk.Key.o);

    var item_file_save = new ImageMenuItem.from_stock (Stock.SAVE, null);
    menu_file.append (item_file_save);
    item_file_save.activate.connect (() => {
        project.buffer_save();
    });
    project.buffer_changed.connect (item_file_save.set_sensitive);
    mwidget.add_accel_activate (item_file_save, Gdk.Key.s);

    menu_file.append (new SeparatorMenuItem());

    var item_file_quit = new ImageMenuItem.from_stock (Stock.QUIT, null);
    menu_file.append (item_file_quit);
    item_file_quit.activate.connect (() => {
        mwidget.on_destroy();
        main_quit();
    });
    mwidget.add_accel_activate (item_file_quit, Gdk.Key.q);

    /* Edit */
    var item_edit = new Gtk.MenuItem.with_mnemonic ("_" + _("Edit"));
    mwidget.add_menu (item_edit);
    var menu_edit = new Gtk.Menu();
    item_edit.set_submenu (menu_edit);

    var item_edit_undo = new ImageMenuItem.from_stock (Stock.UNDO, null);
    item_edit_undo.set_sensitive (false);
    menu_edit.append (item_edit_undo);
    item_edit_undo.activate.connect (undo_change);
    project.undo_changed.connect (item_edit_undo.set_sensitive);
    mwidget.add_accel_activate (item_edit_undo, Gdk.Key.u);

    var item_edit_redo = new ImageMenuItem.from_stock (Stock.REDO, null);
    item_edit_redo.set_sensitive (false);
    menu_edit.append (item_edit_redo);
    item_edit_redo.activate.connect (redo_change);
    project.redo_changed.connect (item_edit_redo.set_sensitive);
    mwidget.add_accel_activate (item_edit_redo, Gdk.Key.r);

    /* View */
    var item_view = new Gtk.MenuItem.with_mnemonic ("_" + _("View"));
    mwidget.add_menu (item_view);
    var menu_view = new Gtk.Menu();
    item_view.set_submenu (menu_view);

    mwidget.add_view_menu_item (menu_view, wdg_search, _("Show search"), true, Gdk.Key.f);
    mwidget.add_view_menu_item (menu_view, wdg_report, _("Show reports"));
    mwidget.add_view_menu_item (menu_view, wdg_pbrw, _("Show project browser"));
    mwidget.add_view_menu_item (menu_view, wdg_build_output, _("Show build output"));
    mwidget.add_view_menu_item (menu_view, wdg_app_output, _("Show application output"));
    mwidget.add_view_menu_item (menu_view, wdg_breakpoints, _("Show breakpoints"));
    mwidget.add_view_menu_item (menu_view, wdg_current_file_structure, _("Show current file structure"));
    mwidget.add_view_menu_item (menu_view, wdg_stylechecker, _("Show stylechecker"));
    mwidget.add_view_menu_item (menu_view, wdg_smb_browser, _("Show symbol browser"));

    var item_view_lockhide = new CheckMenuItem.with_mnemonic ("_" + _("Lock elements"));
    menu_view.append (item_view_lockhide);
    item_view_lockhide.toggled.connect (() => {
        if (item_view_lockhide.active)
            mwidget.lock_items();
        else
            mwidget.unlock_items();
    });
    mwidget.lock_items.connect (() => {
        item_view_lockhide.active = true;
    });
    mwidget.unlock_items.connect (() => {
        item_view_lockhide.active = false;
    });
    mwidget.add_accel_activate (item_view_lockhide, Gdk.Key.h);

    /* Project */
    var item_project = new Gtk.MenuItem.with_mnemonic ("_" + _("Project"));
    item_project.set_sensitive (false);
    mwidget.add_menu (item_project);
    var menu_project = new Gtk.Menu();
    item_project.set_submenu (menu_project);

    /* Help */
    var item_help = new Gtk.MenuItem.with_mnemonic ("_" + _("Help"));
    mwidget.add_menu (item_help);
    var menu_help = new Gtk.Menu();
    item_help.set_submenu (menu_help);

    var item_help_about = new ImageMenuItem.from_stock (Stock.ABOUT, null);
    menu_help.append (item_help_about);
    item_help_about.activate.connect (ui_about_dialog);

    mwidget.menu_finish();
}


/**
 * Build up toolbar.
 */
private void build_toolbar (MainWidget mwidget) {
    var btnReturn = new ToolButton (new Image.from_icon_name ("go-previous-symbolic", IconSize.BUTTON), _("Back"));
    mwidget.add_button (btnReturn);
    btnReturn.set_tooltip_text (_("Close project"));
    btnReturn.clicked.connect (() => {
        mwidget.request_close();
    });

    mwidget.add_button (new SeparatorToolItem());

    var btnNewFile = new ToolButton.from_stock (Stock.NEW);
    mwidget.add_button (btnNewFile);
    btnNewFile.set_tooltip_text (_("Create new file"));
    btnNewFile.clicked.connect (create_new_file);

    /*var btnLoadProject = new ToolButton.from_stock (Stock.OPEN);
    mwidget.add_button (btnLoadProject);
    btnLoadProject.set_tooltip_text (_("Open project"));
    btnLoadProject.clicked.connect (() => {
        ui_load_project();
    });*/

    var btnSave = new ToolButton.from_stock (Stock.SAVE);
    mwidget.add_button (btnSave);
    btnSave.set_tooltip_text (_("Save current file"));
    btnSave.clicked.connect (() => {
        project.buffer_save();
    });
    project.buffer_changed.connect (btnSave.set_sensitive);

    mwidget.add_button (new SeparatorToolItem());

    var btnUndo = new ToolButton.from_stock (Stock.UNDO);
    btnUndo.set_sensitive (false);
    mwidget.add_button (btnUndo);
    btnUndo.set_tooltip_text (_("Undo last change"));
    btnUndo.clicked.connect (undo_change);
    project.undo_changed.connect (btnUndo.set_sensitive);

    var btnRedo = new ToolButton.from_stock (Stock.REDO);
    btnRedo.set_sensitive (false);
    mwidget.add_button (btnRedo);
    btnRedo.set_tooltip_text (_("Redo last change"));
    btnRedo.clicked.connect (redo_change);
    project.redo_changed.connect (btnRedo.set_sensitive);

    mwidget.add_button (new SeparatorToolItem());

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
    mwidget.add_button (ti);

    var btnBuild = new Gtk.ToolButton.from_stock (Stock.EXECUTE);
    mwidget.add_accel_activate (btnBuild, Gdk.Key.b, Gdk.ModifierType.CONTROL_MASK, "clicked");
    mwidget.add_button (btnBuild);
    btnBuild.set_tooltip_text (_("Save current file and build project"));
    btnBuild.clicked.connect (() => {
        project_builder.build_project();
    });

    var btnRun = new Gtk.ToolButton.from_stock (Stock.MEDIA_PLAY);
    mwidget.add_accel_activate (btnRun, Gdk.Key.l, Gdk.ModifierType.CONTROL_MASK, "clicked");
    mwidget.add_button (btnRun);
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
    mwidget.add_button (separator_expand);

    mwidget.add_view_toolbar_item (wdg_search, null, "edit-find-symbolic");

    var btn_lock = new ToggleToolButton();
    btn_lock.icon_name = "changes-prevent-symbolic";
    btn_lock.toggled.connect (() => {
        if (btn_lock.active)
            mwidget.lock_items();
        else
            mwidget.unlock_items();
    });
    mwidget.lock_items.connect (() => {
        btn_lock.active = true;
    });
    mwidget.unlock_items.connect (() => {
        btn_lock.active = false;
    });
    mwidget.add_button (btn_lock);

    mwidget.toolbar_finish();
}

// vim: set ai ts=4 sts=4 et sw=4
