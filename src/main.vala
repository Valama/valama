/**
 * src/main.vala
 * Copyright (C) 2012, Linus Seelinger <S.Linus@gmx.de>
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
using Vala;
using GLib;
using Guanako;

static Window window_main;

static valama_project project;
static SourceView view;
static symbol_browser smb_browser;
static ReportWrapper report_wrapper;
static ui_report wdg_report;

static bool parsing = false;

public static int main (string[] args) {
    Gtk.init (ref args);

    loop_update  = new MainLoop();

    string proj_file;
    if (args.length > 1)
        proj_file = args[1];
    else {
        stderr.printf ("Please pass a .vlp Valama project file. This will change later.");
        return 1;
    }

    project = new valama_project (proj_file);
    var pbrw = new project_browser (project);

    report_wrapper = new ReportWrapper();
    //report_wrapper = project.guanako_project.code_context.report as ReportWrapper;
    project.guanako_project.code_context.report = report_wrapper;
    //report_wrapper = project.guanako_project.code_context.report as ReportWrapper;

    window_main = new Window();

    view = new SourceView();
    view.show_line_numbers = true;
    var bfr = (SourceBuffer) view.buffer;
    bfr.set_highlight_syntax (true);
    view.insert_spaces_instead_of_tabs = true;

    TestProvider tp = new TestProvider();
    tp.priority = 1;
    tp.name = "Test Provider 1";

    try {
        view.completion.add_provider (tp);
    } catch (GLib.Error e) {
        stderr.printf ("Could not load completion: %s", e.message);
        return 1;
    }
    view.buffer.changed.connect (on_view_buffer_changed);
    view.buffer.create_tag ("gray_bg", "background", "gray", null);
    view.auto_indent = true;
    view.indent_width = 4;
    view.buffer.changed.connect (() => {
        if (!parsing) {
            update_text = view.buffer.text;
            //FIXME: warning: GLib.Thread.create has been deprecated since 2.32. Use new Thread<T> ()
            try {
                Thread.create<void*> (update_current_file, true);
            } catch (GLib.ThreadError e) {
                stderr.printf ("Could not create thread to update buffer completion: %s", e.message);
            }
        }
    });

    var langman = new SourceLanguageManager();
    var lang = langman.get_language ("vala");
    bfr.set_language (lang);

    var vbox_main = new Box (Orientation.VERTICAL, 0);

    var toolbar = new Toolbar();
    vbox_main.pack_start (toolbar, false, true);

    var btnLoadProject = new ToolButton.from_stock (Stock.OPEN);
    toolbar.add (btnLoadProject);
    btnLoadProject.set_tooltip_text ("Open project");
    btnLoadProject.clicked.connect (() => {
        ui_load_project(pbrw, smb_browser);
    });

    var btnNewFile = new ToolButton.from_stock (Stock.FILE);
    toolbar.add (btnNewFile);
    btnNewFile.set_tooltip_text ("Create new file");
    btnNewFile.clicked.connect (() => {
        var source_file = ui_create_file_dialog (project);
        if (source_file != null) {
            project.guanako_project.add_source_file (source_file);
            on_source_file_selected (source_file);
            pbrw.build();
            pbrw.symbols_changed();
        }
    });

    var btnSave = new ToolButton.from_stock (Stock.SAVE);
    toolbar.add (btnSave);
    btnSave.set_tooltip_text ("Save current file");
    btnSave.clicked.connect (write_current_source_file);
    toolbar.add (btnSave);

    var btnBuild = new Gtk.ToolButton.from_stock (Stock.EXECUTE);
    btnBuild.set_tooltip_text ("Save current file an build project");
    btnBuild.clicked.connect (on_build_button_clicked);
    toolbar.add (btnBuild);

    var btnAutoIndent = new Gtk.ToolButton.from_stock (Stock.REFRESH);
    btnAutoIndent.set_tooltip_text ("Auto Indent");
    btnAutoIndent.clicked.connect (on_auto_indent_button_clicked);
    toolbar.add (btnAutoIndent);

    var btnSettings = new Gtk.ToolButton.from_stock (Stock.PREFERENCES);
    btnSettings.set_tooltip_text ("Settings");
    btnSettings.clicked.connect (() => {
        ui_project_dialog (project);
    });
    toolbar.add (btnSettings);

    var hbox = new Box (Orientation.HORIZONTAL, 0);

    hbox.pack_start(pbrw.widget, false, true);

    var scrw = new ScrolledWindow (null, null);
    scrw.add(view);
    hbox.pack_start (scrw, true, true);

    var scrw2 = new ScrolledWindow (null, null);
    smb_browser = new symbol_browser (project.guanako_project);
    scrw2.add (smb_browser.widget);
    scrw2.set_size_request (300, 0);
    hbox.pack_start (scrw2, false, true);

    vbox_main.pack_start (hbox, true, true);


    wdg_report = new ui_report (report_wrapper);
    var scrw3 = new ScrolledWindow (null, null);
    scrw3.add (wdg_report.widget);
    scrw3.set_size_request (0, 150);
    vbox_main.pack_start (scrw3, false, true);

    pbrw.source_file_selected.connect(on_source_file_selected);
    pbrw.symbols_changed.connect(()=>{
        smb_browser.build();
    });
    wdg_report.error_selected.connect(on_error_selected);

    window_main.add (vbox_main);
    window_main.hide_titlebar_when_maximized = true;
    window_main.set_default_size (700, 600);
    window_main.destroy.connect (Gtk.main_quit);
    window_main.show_all();

    Gtk.main();

    project.save();
    return 0;
}

MainLoop loop_update;
string update_text;
static void* update_current_file() {
    parsing = true;
    report_wrapper.clear();
    project.guanako_project.update_file (current_source_file, update_text);
    Idle.add (() => {
        wdg_report.build();
        parsing = false;
        if (loop_update.is_running())
            loop_update.quit();
        return false;
    });
    return null;
}

static void on_auto_indent_button_clicked() {
    string indented = Guanako.auto_indent_buffer (project.guanako_project, current_source_file);
    current_source_file.content = indented;
    view.buffer.text = indented;
}

static void on_error_selected (ReportWrapper.Error err) {
    stdout.printf ("Selected: " + err.source.file.filename + "\n");

    on_source_file_selected(err.source.file);

    TextIter start;
#if VALA_LESS_0_18
    view.buffer.get_iter_at_line_offset (out start, err.source.first_line - 1, err.source.first_column - 1);
#else
    view.buffer.get_iter_at_line_offset (out start, err.source.begin.line - 1, err.source.begin.column - 1);
#endif
    TextIter end;
#if VALA_LESS_0_18
    view.buffer.get_iter_at_line_offset (out end, err.source.last_line - 1, err.source.last_column - 1);
#else
    view.buffer.get_iter_at_line_offset (out end, err.source.end.line - 1, err.source.end.column - 1);
#endif
    view.buffer.select_range (start, end);

}

static void on_build_button_clicked() {
    write_current_source_file();
    report_wrapper.clear();
    project.build();
    wdg_report.build();
}

static SourceFile current_source_file = null;
static void on_source_file_selected (SourceFile file){
    if (current_source_file == file)
        return;
    current_source_file = file;

    string txt = "";
    try {
        FileUtils.get_contents (file.filename, out txt);
        view.buffer.text = txt;
    } catch (GLib.FileError e) {
        stderr.printf ("Could not load file: %s", e.message);
    }
}

void write_current_source_file() {
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
        stderr.printf ("Could not update source file: %s", e.message);
    } catch (GLib.Error e) {
        stderr.printf ("Could not open file to write: %s", e.message);
    }

    report_wrapper.clear();
    project.guanako_project.update_file (current_source_file, view.buffer.text);
    wdg_report.build();

    smb_browser.build();
}

static void on_view_buffer_changed(){
}

public class ReportWrapper : Vala.Report {
    public struct Error {
        public Vala.SourceReference source;
        public string message;
    }
    public Vala.List<Error?> errors_list = new Vala.ArrayList<Error?>();
    public Vala.List<Error?> warnings_list = new Vala.ArrayList<Error?>();
    bool general_error = false;
    public void clear() {
        errors_list = new Vala.ArrayList<Error?>();
        warnings_list = new Vala.ArrayList<Error?>();
    }
    public override void warn (Vala.SourceReference? source, string message) {
        warnings ++;

        if (source == null)
            return;
        //lock (errors_list) {
        warnings_list.add(Error() {source = source, message = message});
        //}
     }
     public override void err (Vala.SourceReference? source, string message) {
         errors ++;

         if (source == null) {
             general_error = true;
             return;
         }
         //lock (errors_list) {
         errors_list.add (Error() {source = source, message = message});
         //}
    }
}

class ui_report {
    public ui_report (ReportWrapper report){
        this.report = report;

        tree_view = new TreeView();
        tree_view.insert_column_with_attributes (-1, "Location", new CellRendererText(), "text", 0, null);
        tree_view.insert_column_with_attributes (-1, "Error", new CellRendererText(), "text", 1, null);

        build();

        tree_view.row_activated.connect((path) => {
            int index = path.get_indices()[0];
            if (report.errors_list.size > index)
                error_selected (report.errors_list[index]);
            else
                error_selected (report.warnings_list[index - report.errors_list.size]);
        });
        tree_view.can_focus = false;

        widget = tree_view;
    }

    ReportWrapper report;
    TreeView tree_view;
    public Widget widget;

    public signal void error_selected (ReportWrapper.Error error);

    public void build() {
        var store = new ListStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        foreach (ReportWrapper.Error err in report.errors_list) {
            TreeIter next;
            store.append (out next);
#if VALA_LESS_0_18
            store.set (next, 0, err.source.first_line.to_string(), 1, err.message, -1);
#else
            store.set (next, 0, err.source.begin.line.to_string(), 1, err.message, -1);
#endif
        }
        foreach (ReportWrapper.Error err in report.warnings_list) {
            TreeIter next;
            store.append (out next);
#if VALA_LESS_0_18
            store.set (next, 0, err.source.first_line.to_string(), 1, err.message, -1);
#else
            store.set (next, 0, err.source.begin.line.to_string(), 1, err.message, -1);
#endif
        }
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
                map_icons[type] = new Gdk.Pixbuf.from_file ("/usr/share/pixmaps/valama/element-" + type + "-16.png");
        } catch (Gdk.PixbufError e) {
            stderr.printf ("Could not load pixmap: %s", e.message);
        } catch (GLib.FileError e) {
            stderr.printf ("Could not open pximaps file: %s", e.message);
        } catch (GLib.Error e) {
            stderr.printf ("Pixmap loading failed: %s", e.message);
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
                stderr.printf ("Could not load icon theme: %s", e.message);
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
                param_string = "none";
            vbox.pack_start (new Label ("Parameters:\n" + param_string +
                                        "\n\nReturns:\n" +
                                        mth.return_type.data_type.name));
            info_inner_widget = vbox;
        } else
            info_inner_widget = new Label (prop.symbol.name);

        info_inner_widget.show_all();
        box_info_frame.pack_start (info_inner_widget, true, true);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
