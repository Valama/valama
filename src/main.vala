/*
 * src/main.vala
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

using Gtk;
using Gdl;
using Vala;
using GLib;
using Guanako;

static MainWindow window_main;

static ValamaProject project;
static Guanako.FrankenStein frankenstein;

static bool parsing = false;
static MainLoop loop_update;

//FIXME: Avoid those globals with signals.
static ProjectBrowser pbrw;
static ReportWrapper report_wrapper;
static UiReport wdg_report;
static ProjectBuilder project_builder;

public static int main (string[] args) {
    Intl.textdomain (Config.GETTEXT_PACKAGE);
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);

    // /* Command line parsing. */
    // /* Copied from Yorba application. */
    unowned string[] a = args;
    Gtk.init (ref a);
    // Sanitize the args.  Gtk's init function will leave null elements
    // in the array, which then causes OptionContext to crash.
    // See ticket: https://bugzilla.gnome.org/show_bug.cgi?id=674837
    string[] fixed_args = new string[0];
    for (int i = 0; i < args.length; ++i)
        if (args[i] != null)
            fixed_args += args[i];
    args = fixed_args;

    int ret = Args.parse (a);
    if (ret > 0)
        return ret;
    else if (ret < 0)
        return 0;

    Guanako.debug = Args.debug;


    loop_update  = new MainLoop();

    try {
        if (Args.projectfiles.length > 0)
            project = new ValamaProject (args[1]);
        else {
            project = ui_create_project_dialog();
            if (project == null)
                return 1;
        }
    } catch (LoadingError e) {
        //FIXME: Handle this error (properly) instead of this pseudo hack
        //       (same as above).
        errmsg (_("Couldn't load Valama project: %s\n"), e.message);
        project = null;
        return 1;
    }

    window_main = new MainWindow();
    project_builder = new ProjectBuilder (project);
    frankenstein = new Guanako.FrankenStein();
    var build_output = new BuildOutput();

    /* Ui elements. */
    var ui_elements_pool = new UiElementPool();
    pbrw = new ProjectBrowser (project);
    pbrw.file_selected.connect (on_file_selected);

    var smb_browser = new SymbolBrowser();
    pbrw.connect (smb_browser);
    ui_elements_pool.add (pbrw);
    //ui_elements_pool.add (smb_browser);  // dangerous (circulare deps)

    report_wrapper = new ReportWrapper();
    project.guanako_project.set_report_wrapper (report_wrapper);
    wdg_report = new UiReport (report_wrapper);
    var wdg_breakpoints = new UiBreakpoints (frankenstein);
    wdg_report.error_selected.connect (on_error_selected);
    ui_elements_pool.add (wdg_report);


    /* Menu */
    /* File */
    var item_file = new Gtk.MenuItem.with_mnemonic ("_" + _("File"));
    window_main.add_menu (item_file);

    var menu_file = new Gtk.Menu();
    item_file.set_submenu (menu_file);

    var item_new = new ImageMenuItem.from_stock (Stock.NEW, null);
    menu_file.append (item_new);
    item_new.activate.connect (create_new_file);
    window_main.add_accel_activate (item_new, "n");

    var item_open = new ImageMenuItem.from_stock (Stock.OPEN, null);
    menu_file.append (item_open);
    item_open.activate.connect (() => {
        ui_load_project (ui_elements_pool);
    });
    window_main.add_accel_activate (item_open, "o");

    var item_save = new ImageMenuItem.from_stock (Stock.SAVE, null);
    menu_file.append (item_save);
    item_save.activate.connect (() => {
        project.buffer_save();
    });
    project.buffer_changed.connect (item_save.set_sensitive);
    window_main.add_accel_activate (item_save, "s");

    menu_file.append (new SeparatorMenuItem());

    var item_quit = new ImageMenuItem.from_stock (Stock.QUIT, null);
    menu_file.append (item_quit);
    item_quit.activate.connect (main_quit);
    window_main.add_accel_activate (item_quit, "q");

    /* Edit */
    var item_edit = new Gtk.MenuItem.with_mnemonic ("_" + _("Edit"));
    window_main.add_menu (item_edit);
    var menu_edit = new Gtk.Menu();
    item_edit.set_submenu (menu_edit);

    var item_undo = new ImageMenuItem.from_stock (Stock.UNDO, null);
    item_undo.set_sensitive (false);
    menu_edit.append (item_undo);
    item_undo.activate.connect (undo_change);
    project.undo_changed.connect (item_undo.set_sensitive);
    window_main.add_accel_activate (item_undo, "u");

    var item_redo = new ImageMenuItem.from_stock (Stock.REDO, null);
    item_redo.set_sensitive (false);
    menu_edit.append (item_redo);
    item_redo.activate.connect (redo_change);
    project.redo_changed.connect (item_redo.set_sensitive);
    window_main.add_accel_activate (item_redo, "r");

    /* View */
    var item_view = new Gtk.MenuItem.with_mnemonic ("_" + _("View"));
    item_view.set_sensitive (false);
    window_main.add_menu (item_view);

    /* Project */
    var item_project = new Gtk.MenuItem.with_mnemonic ("_" + _("Project"));
    item_project.set_sensitive (false);
    window_main.add_menu (item_project);

    /* Help */
    var item_help = new Gtk.MenuItem.with_mnemonic ("_" + _("Help"));
    window_main.add_menu (item_help);

    var menu_help = new Gtk.Menu();
    item_help.set_submenu (menu_help);

    var item_about = new ImageMenuItem.from_stock (Stock.ABOUT, null);
    menu_help.append (item_about);
    item_about.activate.connect (ui_about_dialog);


    /* Buttons. */
    var btnNewFile = new ToolButton.from_stock (Stock.NEW);
    window_main.add_button (btnNewFile);
    btnNewFile.set_tooltip_text (_("Create new file"));
    btnNewFile.clicked.connect (create_new_file);

    var btnLoadProject = new ToolButton.from_stock (Stock.OPEN);
    window_main.add_button (btnLoadProject);
    btnLoadProject.set_tooltip_text (_("Open project"));
    btnLoadProject.clicked.connect (() => {
        ui_load_project (ui_elements_pool);
    });

    var btnSave = new ToolButton.from_stock (Stock.SAVE);
    window_main.add_button (btnSave);
    btnSave.set_tooltip_text (_("Save current file"));
    btnSave.clicked.connect (() => {
        project.buffer_save();
    });
    project.buffer_changed.connect (btnSave.set_sensitive);

    window_main.add_button (new SeparatorToolItem());

    var btnUndo = new ToolButton.from_stock (Stock.UNDO);
    btnUndo.set_sensitive (false);
    window_main.add_button (btnUndo);
    btnUndo.set_tooltip_text (_("Undo last change"));
    btnUndo.clicked.connect (undo_change);
    project.undo_changed.connect (btnUndo.set_sensitive);

    var btnRedo = new ToolButton.from_stock (Stock.REDO);
    btnRedo.set_sensitive (false);
    window_main.add_button (btnRedo);
    btnRedo.set_tooltip_text (_("Redo last change"));
    btnRedo.clicked.connect (redo_change);
    project.redo_changed.connect (btnRedo.set_sensitive);

    window_main.add_button (new SeparatorToolItem());

    var target_selector = new ComboBoxText();
    var ti = new ToolItem();
    ti.add (target_selector);
    target_selector.append_text (_("Debug"));
    target_selector.append_text (_("Release"));
    target_selector.active = 0;
    target_selector.changed.connect (()=>{
        window_main.IDEmode = (IDEmodes)target_selector.active;
    });
    window_main.add_button (ti);

    var btnBuild = new Gtk.ToolButton.from_stock (Stock.EXECUTE);
    window_main.add_button (btnBuild);
    btnBuild.set_tooltip_text (_("Save current file and build project"));
    btnBuild.clicked.connect (() => {
        build_output.clear();
        if (window_main.IDEmode == IDEmodes.RELEASE)
            project_builder.build_project();
        else if (window_main.IDEmode == IDEmodes.DEBUG)
            project_builder.build_project (frankenstein);
    });

    var btnRun = new Gtk.ToolButton.from_stock (Stock.MEDIA_PLAY);
    window_main.add_button (btnRun);
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

    window_main.add_button (new SeparatorToolItem());

    /*
    var btnAutoIndent = new Gtk.ToolButton.from_stock (Stock.REFRESH);
    window_main.add_button (btnAutoIndent);
    btnAutoIndent.set_tooltip_text (_("Auto Indent"));
    btnAutoIndent.clicked.connect (on_auto_indent_button_clicked);
    */

    var btnSettings = new Gtk.ToolButton.from_stock (Stock.PREFERENCES);
    window_main.add_button (btnSettings);
    btnSettings.set_tooltip_text (_("Settings"));
    btnSettings.clicked.connect (() => {
        ui_project_dialog (project);
    });


    /* Application signals. */
    window_main.buffer_close.connect (project.close_buffer);

    window_main.notify["current-srcbuffer"].connect (() => {
        var srcbuf = window_main.current_srcbuffer;
        project.undo_changed (srcbuf.can_undo);
        project.redo_changed (srcbuf.can_redo);
        if (window_main.current_srcfocus != _("New document"))
            project.buffer_changed (project.buffer_is_dirty (
                        Path.build_path (Path.DIR_SEPARATOR_S,
                                         project.project_path,
                                         window_main.current_srcfocus)));
        else
            project.buffer_changed (true);
    });


    /* Gdl elements. */
    var src_symbol = new ScrolledWindow (null, null);
    src_symbol.add (smb_browser.widget);

    var src_report = new ScrolledWindow (null, null);
    src_report.add (wdg_report.widget);

    /* Init new empty buffer. */
    window_main.add_srcitem (project.open_new_buffer ("", "", true));
    window_main.add_item ("ReportWrapper", _("Report widget"), src_report,
                          Stock.INFO,
                          DockItemBehavior.CANT_CLOSE, //temporary solution until items can be added later
                          //DockItemBehavior.NORMAL,
                          DockPlacement.BOTTOM);
    window_main.add_item ("ProjectBrowser", _("Project browser"), pbrw.widget,
                          Stock.FILE,
                          DockItemBehavior.CANT_CLOSE,
                          DockPlacement.LEFT);
    window_main.add_item ("BuildOutput", _("Build output"), build_output.widget,
                          Stock.FILE,
                          DockItemBehavior.CANT_CLOSE,
                          DockPlacement.LEFT);
    window_main.add_item ("Breakpoints", _("Breakpoints / Timers"), wdg_breakpoints.widget,
                          Stock.FILE,
                          DockItemBehavior.CANT_CLOSE,
                          DockPlacement.LEFT);
    window_main.add_item ("SymbolBrowser", _("Symbol browser"), src_symbol,
                          Stock.CONVERT,
                          DockItemBehavior.CANT_CLOSE, //temporary solution until items can be added later
                          //DockItemBehavior.NORMAL,
                          DockPlacement.RIGHT);
    window_main.show_all();

    /* Load default layout. Either local one or system wide. */
    string local_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                    Environment.get_user_cache_dir(),
                                                    "valama",
                                                    "layout.xml");
    string system_layout_filename = Path.build_path (Path.DIR_SEPARATOR_S,
                                                     Config.PACKAGE_DATA_DIR,
                                                     "layout.xml");
    if (!window_main.load_layout (local_layout_filename))
        window_main.load_layout (system_layout_filename);

    Gtk.main();

    var f = File.new_for_path (local_layout_filename).get_parent();
    if (!f.query_exists())
        try {
            f.make_directory_with_parents();
        } catch (GLib.Error e) {
            errmsg (_("Couldn't create cache directory: %s\n"), e.message);
        }
    window_main.save_layout (local_layout_filename);
    project.save();
    return 0;
}

static void create_new_file() {
    var source_file = ui_create_file_dialog (project);
    if (source_file != null) {
        project.guanako_project.add_source_file (source_file);
        on_file_selected (source_file.filename);
        pbrw.update();
    }
}

static void undo_change() {
    var srcbuf = window_main.current_srcbuffer;
    var manager = srcbuf.get_undo_manager();
    manager.undo();
}

static void redo_change() {
    var srcbuf = window_main.current_srcbuffer;
    var manager = srcbuf.get_undo_manager();
    manager.redo();
}

// static void on_auto_indent_button_clicked() {
//     string indented = Guanako.auto_indent_buffer (project.guanako_project, current_source_file);
//     current_source_file.content = indented;
//     window_main.current_srcbuffer.text = indented;
// }

static void on_error_selected (ReportWrapper.Error err) {
    on_file_selected (err.source.file.filename);

    var bfr = project.get_buffer_by_file (Path.build_path (Path.DIR_SEPARATOR_S,
                                                           project.project_path,
                                                           err.source.file.filename));
    if (bfr == null)
        return;

    TextIter start;
    bfr.get_iter_at_line_offset (out start,
                                 err.source.begin.line - 1,
                                 err.source.begin.column - 1);
    TextIter end;
    bfr.get_iter_at_line_offset (out end,
                                 err.source.end.line - 1,
                                 err.source.end.column - 1);
    bfr.select_range (start, end);
}


static void on_file_selected (string filename) {
    var pfile = File.new_for_path (project.project_path);
    var fname = pfile.get_relative_path (File.new_for_path (filename));

    if (window_main.current_srcfocus == fname)
        return;

    string txt = "";
    try {
        FileUtils.get_contents (filename, out txt);
        var view = project.open_new_buffer (txt, filename);
        if (view != null)
            window_main.add_srcitem (view, fname);
        window_main.focus_src (fname);
    } catch (GLib.FileError e) {
        errmsg (_("Could not load file: %s\n"), e.message);
    }
}


class TestProvider : Gtk.SourceCompletionProvider, Object {
    Gdk.Pixbuf icon;
    public string name;
    public int priority;
    GLib.List<Gtk.SourceCompletionItem> proposals;

    construct {
        Gdk.Pixbuf icon = this.get_icon();

        this.proposals = new GLib.List<Gtk.SourceCompletionItem>();

        try {
            foreach (string type in new string[] {"class",
                                                  "enum",
                                                  "field",
                                                  "method",
                                                  "namespace",
                                                  "property",
                                                  "struct",
                                                  "signal",
                                                  "constant"})
                map_icons[type] = new Gdk.Pixbuf.from_file (Path.build_path (
                                                Path.DIR_SEPARATOR_S,
                                                Config.PIXMAP_DIR,
                                                "element-" + type + "-16.png"));
        } catch (Gdk.PixbufError e) {
            errmsg (_("Could not load pixmap: %s\n"), e.message);
        } catch (GLib.FileError e) {
            errmsg (_("Could not open pixmaps file: %s\n"), e.message);
        } catch (GLib.Error e) {
            errmsg (_("Pixmap loading failed: %s\n"), e.message);
        }
    }

    Gee.HashMap<string, Gdk.Pixbuf> map_icons = new Gee.HashMap<string, Gdk.Pixbuf>();

    public string get_name() {
        return this.name;
    }

    public int get_priority() {
        return this.priority;
    }

    public bool match (Gtk.SourceCompletionContext context) {
        return true;
    }

    public void populate (Gtk.SourceCompletionContext context) {

        /* Get current line */
        var mark = window_main.current_srcbuffer.get_insert();
        TextIter iter;
        window_main.current_srcbuffer.get_iter_at_mark (out iter, mark);
        var line = iter.get_line() + 1;
        var col = iter.get_line_offset();

        TextIter iter_start;
        window_main.current_srcbuffer.get_iter_at_line (out iter_start, line - 1);
        var current_line = window_main.current_srcbuffer.get_text (iter_start, iter, false);

        if (parsing)
            loop_update.run();

        try {
            new Thread<void*>.try (_("Completion"), () => {
                /* Get completion proposals from Guanako */
                Timer tmr = new Timer();
                tmr.start();
                var guanako_proposals = project.guanako_project.propose_symbols (
                                    project.guanako_project.get_source_file_by_name (
                                            Path.build_path (Path.DIR_SEPARATOR_S,
                                                             project.project_path,
                                                             window_main.current_srcfocus)),
                                    line,
                                    col,
                                    current_line);
	            window_main.title = tmr.elapsed().to_string();
                /* Assign icons and pass the proposals on to Gtk.SourceView */
                var props = new GLib.List<Gtk.SourceCompletionItem>();
                foreach (Gee.TreeSet<CompletionProposal> list in guanako_proposals)
                foreach (CompletionProposal guanako_proposal in list) {
                    if (guanako_proposal.symbol.name != null) {

                        Gdk.Pixbuf pixbuf = null;
                        if (guanako_proposal.symbol      is Namespace)   pixbuf = map_icons["namespace"];
                        else if (guanako_proposal.symbol is Property)    pixbuf = map_icons["property"];
                        else if (guanako_proposal.symbol is Struct)      pixbuf = map_icons["struct"];
                        else if (guanako_proposal.symbol is Method)      pixbuf = map_icons["method"];
                        else if (guanako_proposal.symbol is Variable)    pixbuf = map_icons["field"];
                        else if (guanako_proposal.symbol is Enum)        pixbuf = map_icons["enum"];
                        else if (guanako_proposal.symbol is Class)       pixbuf = map_icons["class"];
                        else if (guanako_proposal.symbol is Constant)    pixbuf = map_icons["constant"];
                        else if (guanako_proposal.symbol is Vala.Signal) pixbuf = map_icons["signal"];

                        var item = new ComplItem (guanako_proposal.symbol.name,
                                                  guanako_proposal.symbol.name,
                                                  pixbuf,
                                                  null,
                                                  guanako_proposal);
                        props.append (item);
                    }
                }
                GLib.Idle.add (() => {
                    if (context is SourceCompletionContext)
                        context.add_proposals (this, props, true);
                    return false;
                });
                return null;
            });
        } catch (GLib.Error e) {
            stderr.printf (_("Could not launch completion thread successfully: %s\n"), e.message);
        }
    }

    public unowned Gdk.Pixbuf? get_icon() {
        if (this.icon == null) {
            Gtk.IconTheme theme = Gtk.IconTheme.get_default();
            try {
                this.icon = theme.load_icon (Gtk.Stock.DIALOG_INFO, 16, 0);
            } catch (GLib.Error e) {
                errmsg (_("Could not load icon theme: %s\n"), e.message);
            }
        }
        return this.icon;
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal,
                                   Gtk.TextIter iter) {
        var prop = ((ComplItem)proposal).guanako_proposal;

        TextIter start = iter;
        start.backward_chars (prop.replace_length);

        window_main.current_srcbuffer.delete (ref start, ref iter);
        window_main.current_srcbuffer.insert (ref start, prop.symbol.name, prop.symbol.name.length);
        return true;
    }

    public Gtk.SourceCompletionActivation get_activation() {
        return Gtk.SourceCompletionActivation.INTERACTIVE |
               Gtk.SourceCompletionActivation.USER_REQUESTED;
    }

    Box box_info_frame = new Box (Orientation.VERTICAL, 0);
    Widget info_inner_widget = null;
    public unowned Gtk.Widget? get_info_widget (Gtk.SourceCompletionProposal proposal) {
        return box_info_frame;
    }

    public int get_interactive_delay() {
        return -1;
    }

    public bool get_start_iter (Gtk.SourceCompletionContext context,
                                Gtk.SourceCompletionProposal proposal,
                                Gtk.TextIter iter) {
        var mark = window_main.current_srcbuffer.get_insert();
        TextIter cursor_iter;
        window_main.current_srcbuffer.get_iter_at_mark (out cursor_iter, mark);

        var prop = ((ComplItem)proposal).guanako_proposal;
        cursor_iter.backward_chars (prop.replace_length);
        iter = cursor_iter;
        return true;
    }

    public void update_info (Gtk.SourceCompletionProposal proposal,
                             Gtk.SourceCompletionInfo info) {
        if (info_inner_widget != null) {
            info_inner_widget.destroy();
            info_inner_widget = null;
        }

        var prop = ((ComplItem)proposal).guanako_proposal;
        if (prop is Method) {
            var mth = prop.symbol as Method;
            var vbox = new Box (Orientation.VERTICAL, 0);
            string param_string = "";
            foreach (Vala.Parameter param in mth.get_parameters())
                param_string += param.variable_type.data_type.name + " " + param.name + ", ";
            if (param_string.length > 1)
                param_string = param_string.substring (0, param_string.length - 2);
            else
                param_string = _("none");
            vbox.pack_start (new Label (_("Parameters:\n") + param_string +
                                        _("\n\nReturns:\n") +
                                        mth.return_type.data_type.name));
            info_inner_widget = vbox;
        } else
            info_inner_widget = new Label (prop.symbol.name);

        info_inner_widget.show_all();
        box_info_frame.pack_start (info_inner_widget, true, true);
    }
}

/**
 * {@link Gtk.SourceCompletionItem} enhanced to carry a reference to the
 * corresponding Guanako proposal.
 */
class ComplItem : SourceCompletionItem {
    public ComplItem (string label, string text, Gdk.Pixbuf? icon, string? info, CompletionProposal guanako_proposal) {
        Object (label: label, text: text, icon: icon, info: info);
        this.guanako_proposal = guanako_proposal;
    }
    public CompletionProposal guanako_proposal;
}
// vim: set ai ts=4 sts=4 et sw=4
