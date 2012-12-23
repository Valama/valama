/*
 * src/main.vala
 * Copyright (C) 2012, Linus Seelinger <S.Linus@gmx.de>
 *               2012, Dominique Lasserre <lasserre.d@gmail.com>
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
using Pango; // fonts

static MainWindow window_main;

static ValamaProject project;
static SourceView view;

static bool parsing = false;
static MainLoop loop_update;
static SourceFile current_source_file = null;

public static int main (string[] args) {
    Intl.textdomain (Config.GETTEXT_PACKAGE);
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);

    //TODO: Command line parsing.
    Gtk.init (ref args);

    loop_update  = new MainLoop();

    try {
        if (args.length > 1)
            project = new ValamaProject(args[1]);
        else {
            project = ui_create_project_dialog();
            if (project == null)
                return 1;
        }
    } catch (LoadingError e) {
        //FIXME: Handle this error (properly) instead of this pseudo hack
        //       (same as above).
        stderr.printf (_("Couldn't load Valama project: %s"), e.message);
        project = null;
        return 1;
    }

    window_main = new MainWindow();

    /* Ui elements. */
    var ui_elements_pool = new UiElementPool();
    var pbrw = new ProjectBrowser (project);
    pbrw.source_file_selected.connect (on_source_file_selected);

    var smb_browser = new SymbolBrowser();
    pbrw.connect (smb_browser);
    ui_elements_pool.add (pbrw);
    //ui_elements_pool.add (smb_browser);  // dangerous (circulare deps)

    var report_wrapper = new ReportWrapper();
    project.guanako_project.set_report_wrapper (report_wrapper);
    var wdg_report = new UiReport (report_wrapper);
    wdg_report.error_selected.connect (on_error_selected);
    ui_elements_pool.add (wdg_report);


    /* Source view. */
    view = new SourceView();
    view.show_line_numbers = true;
    view.insert_spaces_instead_of_tabs = true;
    view.override_font(FontDescription.from_string ("Monospace 10"));
    view.buffer.create_tag ("gray_bg", "background", "gray", null);
    view.auto_indent = true;
    view.indent_width = 4;

    var bfr = (SourceBuffer) view.buffer;
    bfr.set_highlight_syntax (true);
    var langman = new SourceLanguageManager();
    var lang = langman.get_language ("vala");
    bfr.set_language (lang);


    /* Completion provider. */
    TestProvider tp = new TestProvider();
    tp.priority = 1;
    tp.name = _("Test Provider 1");

    try {
        view.completion.add_provider (tp);
    } catch (GLib.Error e) {
        stderr.printf (_("Could not load completion: %s"), e.message);
        return 1;
    }

    view.buffer.changed.connect (() => {
        if (!parsing) {
            try {
#if NOT_THREADED
                Thread<void*> t = new Thread<void*>.try (_("Buffer update"), () => {
#else
                new Thread<void*>.try (_("Buffer update"), () => {
#endif
                    parsing = true;
                    report_wrapper.clear();
                    project.guanako_project.update_file (current_source_file, view.buffer.text);
                    Idle.add (() => {
                        wdg_report.update();
                        parsing = false;
                        if (loop_update.is_running())
                            loop_update.quit();
                        return false;
                    });
                    return null;
                });
#if NOT_THREADED
                t.join();
#endif
            } catch (GLib.Error e) {
                stderr.printf (_("Could not create thread to update buffer completion: %s"), e.message);
            }
        }
    });


    /* Buttons. */
    var btnLoadProject = new ToolButton.from_stock (Stock.OPEN);
    window_main.add_button (btnLoadProject);
    btnLoadProject.set_tooltip_text (_("Open project"));
    btnLoadProject.clicked.connect (() => {
        ui_load_project (ui_elements_pool);
    });

    var btnNewFile = new ToolButton.from_stock (Stock.FILE);
    window_main.add_button (btnNewFile);
    btnNewFile.set_tooltip_text (_("Create new file"));
    btnNewFile.clicked.connect (() => {
        var source_file = ui_create_file_dialog (project);
        if (source_file != null) {
            project.guanako_project.add_source_file (source_file);
            on_source_file_selected (source_file);
            pbrw.update();
        }
    });

    var btnSave = new ToolButton.from_stock (Stock.SAVE);
    window_main.add_button (btnSave);
    btnSave.set_tooltip_text (_("Save current file"));
    btnSave.clicked.connect (() => {
        write_current_source_file(report_wrapper);
        wdg_report.update();
    });

    var btnBuild = new Gtk.ToolButton.from_stock (Stock.EXECUTE);
    window_main.add_button (btnBuild);
    btnBuild.set_tooltip_text (_("Save current file and build project"));
    btnBuild.clicked.connect (() => {
        on_build_button_clicked (report_wrapper);
        wdg_report.update();
    });

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


    /* Gdl elements. */
    var scr_view = new ScrolledWindow (null, null);
    scr_view.add (view);

    var scr_symbol = new ScrolledWindow (null, null);
    scr_symbol.add (smb_browser.widget);

    var scr_report = new ScrolledWindow (null, null);
    scr_report.add (wdg_report.widget);

    window_main.add_item ("SourceView", _("Source view"), scr_view,
                          Stock.EDIT,
                          DockItemBehavior.LOCKED,
                          DockPlacement.TOP);
    window_main.add_item ("ReportWrapper", _("Report widget"), scr_report,
                          Stock.INFO,
                          DockItemBehavior.CANT_CLOSE, //temporary solution until items can be added later
                          //DockItemBehavior.NORMAL,
                          DockPlacement.BOTTOM);
    window_main.add_item ("ProjectBrowser", _("Project browser"), pbrw.widget,
                          Stock.FILE,
                          DockItemBehavior.CANT_CLOSE,
                          DockPlacement.LEFT);
    window_main.add_item ("SymbolBrowser", _("Symbol browser"), scr_symbol,
                          Stock.CONVERT,
                          DockItemBehavior.CANT_CLOSE, //temporary solution until items can be added later
                          //DockItemBehavior.NORMAL,
                          DockPlacement.RIGHT);
    window_main.show_all();

    /* Load default layout. Either local one or system wide. */
    string local_layout_filename = Environment.get_user_cache_dir() + "/valama/layout.xml";
    string system_layout_filename = Config.PACKAGE_DATA_DIR + "/layout.xml";
    if (!window_main.load_layout (local_layout_filename))
        window_main.load_layout (system_layout_filename);

    Gtk.main();

    var f = File.new_for_path (local_layout_filename).get_parent();
    if (!f.query_exists())
        try {
            f.make_directory_with_parents();
        } catch (GLib.Error e) {
            stderr.printf (_("Couldn't create cache directory: %s"), e.message);
        }
    window_main.save_layout (local_layout_filename);
    project.save();
    return 0;
}

static void on_auto_indent_button_clicked() {
    string indented = Guanako.auto_indent_buffer (project.guanako_project, current_source_file);
    current_source_file.content = indented;
    view.buffer.text = indented;
}

static void on_error_selected (ReportWrapper.Error err) {
    on_source_file_selected (err.source.file);

    TextIter start;
    view.buffer.get_iter_at_line_offset (out start,
#if VALA_LESS_0_18
                                         err.source.first_line - 1,
                                         err.source.first_column - 1);
#else
                                         err.source.begin.line - 1,
                                         err.source.begin.column - 1);
#endif
    TextIter end;
    view.buffer.get_iter_at_line_offset (out end,
#if VALA_LESS_0_18
                                         err.source.last_line - 1,
                                         err.source.last_column - 1);
#else
                                         err.source.end.line - 1,
                                         err.source.end.column - 1);
#endif
    view.buffer.select_range (start, end);
}

static void on_build_button_clicked (ReportWrapper report_wrapper) {
    write_current_source_file (report_wrapper);
    project.build();
}

static void on_source_file_selected (SourceFile file){
    if (current_source_file == file)
        return;
    current_source_file = file;

    string txt = "";
    try {
        FileUtils.get_contents (file.filename, out txt);
        view.buffer.text = txt;
    } catch (GLib.FileError e) {
        stderr.printf (_("Could not load file: %s"), e.message);
    }
}

void write_current_source_file (ReportWrapper report_wrapper) {
    var file = File.new_for_path (current_source_file.filename);
    /* TODO: First parameter can be used to check if file has changed.
     *       The second parameter can enable/disable backup file. */
    try {
        var fos = file.replace (null, false, FileCreateFlags.REPLACE_DESTINATION);
        var dos = new DataOutputStream (fos);
        dos.put_string (view.buffer.text);
        dos.flush();
        dos.close();
    } catch (GLib.IOError e) {
        stderr.printf (_("Could not update source file: %s"), e.message);
    } catch (GLib.Error e) {
        stderr.printf (_("Could not open file to write: %s"), e.message);
    }

    report_wrapper.clear();
    project.guanako_project.update_file (current_source_file, view.buffer.text);
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
                map_icons[type] = new Gdk.Pixbuf.from_file (Config.PIXMAP_DIR + "/element-" + type + "-16.png");
        } catch (Gdk.PixbufError e) {
            stderr.printf (_("Could not load pixmap: %s"), e.message);
        } catch (GLib.FileError e) {
            stderr.printf (_("Could not open pximaps file: %s"), e.message);
        } catch (GLib.Error e) {
            stderr.printf (_("Pixmap loading failed: %s"), e.message);
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
    GLib.List<Gtk.SourceCompletionItem> props;
    Symbol[] props_symbols;
    Gee.HashMap<Gtk.SourceCompletionProposal, CompletionProposal> map_proposals;

    public void populate (Gtk.SourceCompletionContext context) {
        props = new GLib.List<Gtk.SourceCompletionItem>();
        props_symbols = new Symbol[0];

        var mark = view.buffer.get_insert();
        TextIter iter;
        view.buffer.get_iter_at_mark (out iter, mark);
        var line = iter.get_line() + 1;
        var col = iter.get_line_offset();

        TextIter iter_start;
        view.buffer.get_iter_at_line (out iter_start, line - 1);
        var current_line = view.buffer.get_text (iter_start, iter, false);

        string[] splt = current_line.split_set (" .(,");
        string last = "";
        if (splt.length > 0)
            last = splt[splt.length - 1];

        if (parsing)
            loop_update.run();

        map_proposals = new Gee.HashMap<Gtk.SourceCompletionProposal, CompletionProposal>();
        var proposals = project.guanako_project.propose_symbols (current_source_file, line, col, current_line);
        foreach (CompletionProposal proposal in proposals) {
            if (proposal.symbol.name != null) {

                Gdk.Pixbuf pixbuf = null;
                if (proposal.symbol is Namespace)   pixbuf = map_icons["namespace"];
                if (proposal.symbol is Property)    pixbuf = map_icons["property"];
                if (proposal.symbol is Struct)      pixbuf = map_icons["struct"];
                if (proposal.symbol is Method)      pixbuf = map_icons["method"];
                if (proposal.symbol is Variable)    pixbuf = map_icons["field"];
                if (proposal.symbol is Enum)        pixbuf = map_icons["enum"];
                if (proposal.symbol is Class)       pixbuf = map_icons["class"];
                if (proposal.symbol is Constant)    pixbuf = map_icons["constant"];
                if (proposal.symbol is Vala.Signal) pixbuf = map_icons["signal"];

                var item = new Gtk.SourceCompletionItem (proposal.symbol.name, proposal.symbol.name, pixbuf, null);
                props.append (item);
                map_proposals[item] = proposal;
            }
        }

        context.add_proposals (this, props, true);
    }

    public unowned Gdk.Pixbuf? get_icon()
    {
        if (this.icon == null)
        {
            Gtk.IconTheme theme = Gtk.IconTheme.get_default();
            try {
                this.icon = theme.load_icon (Gtk.Stock.DIALOG_INFO, 16, 0);
            } catch (GLib.Error e) {
                stderr.printf (_("Could not load icon theme: %s"), e.message);
            }
        }
        return this.icon;
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal,
                                   Gtk.TextIter iter) {
        var prop = map_proposals[proposal];

        TextIter start = iter;
        start.backward_chars (prop.replace_length);

        view.buffer.delete (ref start, ref iter);
        view.buffer.insert (ref start, prop.symbol.name, prop.symbol.name.length);
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
        return false;
    }

    public void update_info (Gtk.SourceCompletionProposal proposal,
                             Gtk.SourceCompletionInfo info) {
        if (info_inner_widget != null) {
            info_inner_widget.destroy();
            info_inner_widget = null;
        }

        var prop = map_proposals[proposal];
        if (prop is Method) {
            var mth = prop.symbol as Method;
            var vbox = new Box(Orientation.VERTICAL, 0);
            string param_string = "";
            foreach (Vala.Parameter param in mth.get_parameters())
                param_string += param.variable_type.data_type.name + " " + param.name + ", ";
            if (param_string.length > 1)
                param_string = param_string.substring(0, param_string.length - 2);
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

// vim: set ai ts=4 sts=4 et sw=4
