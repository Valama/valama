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

static Window window_main;

static valama_project project;
static SourceView view;
static symbol_browser smb_browser;
static ReportWrapper report_wrapper;
static ui_report wdg_report;

public static void main(string[] args){
    Gtk.init(ref args);

    string sourcedir = Environment.get_current_dir();
    if (args.length > 1)
        sourcedir = args[1];

    project = new valama_project(sourcedir);

    report_wrapper = new ReportWrapper();
    //report_wrapper = project.guanako_project.code_context.report as ReportWrapper;
    project.guanako_project.code_context.report = report_wrapper;
    //report_wrapper = project.guanako_project.code_context.report as ReportWrapper;

    window_main = new Window();

    view = new SourceView();
    view.show_line_numbers = true;
    var bfr = (SourceBuffer)view.buffer;
    bfr.set_highlight_syntax(true);
    view.insert_spaces_instead_of_tabs = true;

    TestProvider tp = new TestProvider ();
    tp.priority = 1;
    tp.name = "Test Provider 1";

    view.completion.add_provider (tp);
    view.buffer.changed.connect(on_view_buffer_changed);
    view.buffer.create_tag("gray_bg", "background", "gray", null);
    view.auto_indent = true;
    view.indent_width = 4;

    var langman = new SourceLanguageManager();
    var lang = langman.get_language("vala");
    bfr.set_language(lang);

    var vbox_main = new VBox(false, 0);

    var toolbar = new Toolbar();
    vbox_main.pack_start(toolbar, false, true);

    var btnSave = new ToolButton.from_stock(Stock.SAVE);
    toolbar.add(btnSave);
    btnSave.clicked.connect(write_current_source_file);

    var btnBuild = new Gtk.ToolButton.from_stock(Stock.EXECUTE);
    btnBuild.clicked.connect(on_build_button_clicked);
    toolbar.add(btnBuild);

    var btnAutoIndent = new Gtk.ToolButton.from_stock(Stock.REFRESH);
    btnAutoIndent.clicked.connect(on_auto_indent_button_clicked);
    toolbar.add(btnAutoIndent);

        var hbox = new HBox(false, 0);

        var pbrw = new project_browser(project);
        hbox.pack_start(pbrw.widget, false, true);
        pbrw.source_file_selected.connect(on_source_file_selected);

        var scrw = new ScrolledWindow(null, null);
        scrw.add(view);
        hbox.pack_start(scrw, true, true);

        var scrw2 = new ScrolledWindow(null, null);
        smb_browser = new symbol_browser(project.guanako_project);
        scrw2.add(smb_browser.widget);
        scrw2.set_size_request(300, 0);
        hbox.pack_start(scrw2, false, true);

    vbox_main.pack_start(hbox, true, true);


    wdg_report = new ui_report(report_wrapper);
    wdg_report.error_selected.connect(on_error_selected);
    var scrw3 = new ScrolledWindow(null, null);
    scrw3.add(wdg_report.widget);
    scrw3.set_size_request(0, 150);
    vbox_main.pack_start(scrw3, false, true);


    window_main.add(vbox_main);
    window_main.hide_titlebar_when_maximized = true;
    window_main.set_default_size(700, 600);
    window_main.destroy.connect(Gtk.main_quit);
    window_main.show_all();

    Gtk.main();
}

static void on_auto_indent_button_clicked(){
    Guanako.auto_indent_buffer(view.buffer);
}

static void on_error_selected(ReportWrapper.Error err){
    stdout.printf("Selected: " + err.source.file.filename + "\n");

    on_source_file_selected(err.source.file);

    TextIter start;
    view.buffer.get_iter_at_line_offset(out start, err.source.first_line - 1, err.source.first_column - 1);
    TextIter end;
    view.buffer.get_iter_at_line_offset(out end, err.source.last_line - 1, err.source.last_column - 1);
    view.buffer.select_range(start, end);

}

static void on_build_button_clicked(){
    write_current_source_file();
    report_wrapper.clear();
    project.build();
    wdg_report.build();
}

static SourceFile current_source_file = null;
static void on_source_file_selected(SourceFile file){
    if (current_source_file == file)
        return;
    current_source_file = file;

    string txt = "";
    FileUtils.get_contents(file.filename, out txt);
    view.buffer.text = txt;
}

void write_current_source_file(){
    var file = File.new_for_path (current_source_file.filename);

    // delete if file already exists
    if (file.query_exists ()) {
        file.delete ();
    }

    var dos = new DataOutputStream (file.create (FileCreateFlags.REPLACE_DESTINATION));
    dos.put_string (view.buffer.text);

report_wrapper.clear();
    project.guanako_project.update_file(current_source_file, view.buffer.text);
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
    public void clear(){
        errors_list = new Vala.ArrayList<Error?>();
        warnings_list = new Vala.ArrayList<Error?>();
    }
    public override void warn (Vala.SourceReference? source, string message) {
        warnings ++;

         if (source == null)
             return;
         //lock (errors_list) {
         warnings_list.add(Error () {source = source, message = message});
         //}
     }
     public override void err (Vala.SourceReference? source, string message) {
         errors ++;

         if (source == null) {
             general_error = true;
             return;
         }
         //lock (errors_list) {
         errors_list.add(Error () {source = source, message = message});
         //}
    }
}

class ui_report {
    public ui_report(ReportWrapper report){
        this.report = report;

        tree_view = new TreeView ();
        tree_view.insert_column_with_attributes (-1, "Location", new CellRendererText (), "text", 0, null);
        tree_view.insert_column_with_attributes (-1, "Error", new CellRendererText (), "text", 1, null);

        build();

        tree_view.row_activated.connect((path)=>{
            int index = path.get_indices()[0];
            if (report.errors_list.size > index)
                error_selected(report.errors_list[index]);
            else
                error_selected(report.warnings_list[index - report.errors_list.size]);
       });
       tree_view.can_focus = false;

        widget = tree_view;
    }

    ReportWrapper report;
    TreeView tree_view;
    public Widget widget;

    public signal void error_selected(ReportWrapper.Error error);

    public void build(){
        var store = new ListStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        foreach (ReportWrapper.Error err in report.errors_list){
            TreeIter next;
            store.append (out next);
            store.set (next, 0, err.source.first_line.to_string(), 1, err.message, -1);
        }
        foreach (ReportWrapper.Error err in report.warnings_list){
            TreeIter next;
            store.append (out next);
            store.set (next, 0, err.source.first_line.to_string(), 1, err.message, -1);
        }
    }
}

class TestProvider : Gtk.SourceCompletionProvider, Object
{
    Gdk.Pixbuf icon;
    public string name;
    public int priority;
    GLib.List<Gtk.SourceCompletionItem> proposals;

    construct
    {
        Gdk.Pixbuf icon = this.get_icon ();

        this.proposals = new GLib.List<Gtk.SourceCompletionItem> ();
        this.proposals.prepend (new Gtk.SourceCompletionItem ("Proposal 3", "Proposal 3", null, null));
        this.proposals.prepend (new Gtk.SourceCompletionItem ("Proposal 2", "Proposal 2", null, null));
        this.proposals.prepend (new Gtk.SourceCompletionItem ("Proposal 1", "Proposal 1", null, null));
    }

    public string get_name ()
    {
        return this.name;
    }

    public int get_priority ()
    {
        return this.priority;
    }

    public bool match (Gtk.SourceCompletionContext context)
    {
        return true;
    }
    GLib.List<Gtk.SourceCompletionItem> props;
    Symbol[] props_symbols;

    public void populate (Gtk.SourceCompletionContext context)
    {
        props = new GLib.List<Gtk.SourceCompletionItem> ();
        props_symbols = new Symbol[0];

        var mark = view.buffer.get_insert();
        TextIter iter;
        view.buffer.get_iter_at_mark(out iter, mark);
        var line = iter.get_line() + 1;
        var col = iter.get_line_offset();

        TextIter iter_start;
        view.buffer.get_iter_at_line(out iter_start, line - 1);
        var current_line = view.buffer.get_text(iter_start, iter, false);

        string[] splt = current_line.split_set(" .(,");
        string last = "";
        if (splt.length > 0)
            last = splt[splt.length - 1];

        var proposals = project.guanako_project.propose_symbols(current_source_file, line, col, current_line);
        foreach (Symbol proposal in proposals){
            if (proposal.name != null){
                /*if (proposal.name.has_prefix(last)){
                    props.append(new Gtk.SourceCompletionItem (proposal.name, proposal.name, null, null));
                    props_symbols += proposal;
                }*/
                props.append(new Gtk.SourceCompletionItem (proposal.name, proposal.name, null, null));
            }
        }

        context.add_proposals (this, props, true);
    }

    public unowned Gdk.Pixbuf? get_icon ()
    {
        if (this.icon == null)
        {
            Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
            this.icon = theme.load_icon (Gtk.STOCK_DIALOG_INFO, 16, 0);
        }
        return this.icon;
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal,
                                   Gtk.TextIter iter)
    {
        return true;
    }

    public Gtk.SourceCompletionActivation get_activation ()
    {
        return Gtk.SourceCompletionActivation.INTERACTIVE |
              Gtk.SourceCompletionActivation.USER_REQUESTED;
    }

    public unowned Gtk.Widget? get_info_widget (Gtk.SourceCompletionProposal proposal)
    {
        return null;
    }

    public int get_interactive_delay ()
    {
        return -1;
    }

    public bool get_start_iter (Gtk.SourceCompletionContext context,
                                Gtk.SourceCompletionProposal proposal,
                                Gtk.TextIter iter)
    {
        return false;
    }

    public void update_info (Gtk.SourceCompletionProposal proposal,
                             Gtk.SourceCompletionInfo info)
    {
    }
}

// vim: set ai ts=4 sts=4 et sw=4
