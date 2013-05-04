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

static Window window_main;
static MainWidget? widget_main = null;
static RecentManager recentmgr;
static WelcomeScreen? vscreen = null;
static Valama gtk_app;

public static int main (string[] args) {
    Intl.textdomain (Config.GETTEXT_PACKAGE);
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    recentmgr = (RecentManager) GLib.Object.new (typeof(RecentManager),
            filename: Path.build_path (Path.DIR_SEPARATOR_S,
                                       Environment.get_user_cache_dir(),
                                       "valama",
                                       "recent_projects.xml"));

    /* Command line parsing. */
    /* Copied from Yorba application. */
    unowned string[] a = args;
    Gtk.init (ref a);
    /*
     * Sanitize the command line arguments. Gtk's init function will leave
     * null elements in the array, which then causes OptionContext to crash.
     * See ticket: https://bugzilla.gnome.org/show_bug.cgi?id=674837
     */
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

    if (Args.debuglevel >= 1)
        Guanako.debug = true;

    if (Args.projectfiles.length > 0)
        try {
            project = new ValamaProject (Args.projectfiles[0], Args.syntaxfile);
        } catch (LoadingError e) {
            errmsg (_("Couldn't load Valama project: %s\n"), e.message);
            project = null;
        }

    load_icons();

    gtk_app = new Valama ();
    return gtk_app.run();
}

static bool quit_valama() {
    if (project != null)
        if (!project.close())
            return false;
    if (widget_main != null)
        widget_main.close();
    window_main.destroy();
    return true;
}

public class Valama : Gtk.Application {
    public Valama () {
        Object (application_id: "app.valama", flags: GLib.ApplicationFlags.FLAGS_NONE);
    }

    public override void activate () {
        window_main = new ApplicationWindow(gtk_app);
        window_main.title = _("Valama");
        window_main.hide_titlebar_when_maximized = true;
        window_main.set_default_size (1200, 600);
        window_main.maximize();

        window_main.delete_event.connect (()=>{
            return !quit_valama();
        });

        window_main.show();
        vscreen = new WelcomeScreen();
        vscreen.project_loaded.connect ((project) => {
            if (project != null) {
                window_main.remove (vscreen);
                show_main_screen (project);
            }
        });
        if (project != null)
            show_main_screen (project);
        else
            window_main.add (vscreen);
    }
}

static void show_main_screen (ValamaProject load_project) {
    project = load_project;
    widget_main = new MainWidget();
    widget_main.init();
    window_main.add (widget_main);
    window_main.add_accel_group (widget_main.accel_group);

    /* Open default source files. */
    var focus = true;
    foreach (var file in project.files_opened) {
        on_file_selected (file, focus);
        focus = false;
    }

    /* Application signals. */
    source_viewer.buffer_close.connect (project.close_buffer);

    source_viewer.current_sourceview_changed.connect (() => {
        var srcbuf = source_viewer.current_srcbuffer;
        project.undo_changed (srcbuf.can_undo);
        project.redo_changed (srcbuf.can_redo);
        if (!is_new_document (source_viewer.current_srcfocus))
            project.buffer_changed (project.buffer_is_dirty (
                                            source_viewer.current_srcfocus));
        else
            project.buffer_changed (true);
    });
    widget_main.request_close.connect (() => {
        widget_main.close();
        window_main.remove (widget_main);
        project = null;
        window_main.add (vscreen);
        widget_main = null;
    });
}

static void load_icons() {
    map_icons = new Gee.HashMap<string, Gdk.Pixbuf>();

    var imagedir = File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S,
                                                       Config.PIXMAP_DIR));
    if (!imagedir.query_exists()) {
        warning_msg (_("Pixmap directory does not exist. No application icons can be used.\n"));
        return;
    }
    var type_regex = /^element-[a-zA-Z_-]+-16\.png$/;

    try {
        var enumerator = imagedir.enumerate_children ("standard::*", FileQueryInfoFlags.NONE, null);
        FileInfo? info = null;
        while ((info = enumerator.next_file()) != null) {
            if (info.get_file_type() == FileType.DIRECTORY)
                continue;
            if (type_regex.match (info.get_name()))
                try {
                        var pixmappath = Path.build_path (Path.DIR_SEPARATOR_S,
                                                          Config.PIXMAP_DIR,
                                                          info.get_name());
                        map_icons[info.get_name()] = new Gdk.Pixbuf.from_file (pixmappath);
                        debug_msg_level (3, _("Load pixmap: %s\n"), pixmappath);
                } catch (Gdk.PixbufError e) {
                    errmsg (_("Could not load pixmap: %s\n"), e.message);
                } catch (GLib.FileError e) {
                    errmsg (_("Could not open pixmaps file: %s\n"), e.message);
                } catch (GLib.Error e) {
                    errmsg (_("Pixmap loading failed: %s\n"), e.message);
                }
        }
    } catch (GLib.Error e) {
        warning_msg (_("Could not list or iterate through directory content of '%s': %s\n"),
                     imagedir.get_path(), e.message);
    }
}

static string? get_symbol_type_name (Symbol symbol) {
    if (symbol is Class)        return "class";
    if (symbol is Constant)     return "constant";
    if (symbol is Delegate)     return "delegate";
    if (symbol is Enum)         return "enum";
    if (symbol is Vala.EnumValue) return "enum_value";
    if (symbol is ErrorCode)    return "error_code";
    if (symbol is ErrorDomain)  return "error_domain";
    if (symbol is Variable)     return "field";
    if (symbol is Interface)    return "interface";
    if (symbol is Method)       return "method";
    if (symbol is Namespace)    return "namespace";
    if (symbol is Property)     return "property";
    if (symbol is Vala.Signal)  return "signal";
    if (symbol is Struct)       return "struct";
    return null;
}

static Gdk.Pixbuf? get_pixbuf_for_symbol (Symbol symbol) {
    var complete_typename = "element-" + get_symbol_type_name(symbol);

    if (!(symbol is Vala.Signal))
        switch (symbol.access) {
            case SymbolAccessibility.INTERNAL:  //TODO: Add internal icons
            case SymbolAccessibility.PRIVATE:
                complete_typename += "-private";
                break;
            case SymbolAccessibility.PUBLIC:
                if (!(symbol is Namespace))
                    complete_typename += "-public";
                break;
            case SymbolAccessibility.PROTECTED:
                if (!(symbol is Field))
                    complete_typename += "-protected";
                break;
        }

    complete_typename += "-16.png";
    if (map_icons.has_key (complete_typename))
        return map_icons[complete_typename];
    return null;
}

static void create_new_file() {
    var filename = ui_create_file_dialog (null, "vala");
    if (filename != null) {
        project.add_source_file (filename);
        source_viewer.focus_src (filename);
    }
}

static void undo_change() {
    var srcbuf = source_viewer.current_srcbuffer;
    var manager = srcbuf.get_undo_manager();
    manager.undo();
}

static void redo_change() {
    var srcbuf = source_viewer.current_srcbuffer;
    var manager = srcbuf.get_undo_manager();
    manager.redo();
}

//NOTE: Disabled due to #4.
// static void on_auto_indent_button_clicked() {
//     string indented = Guanako.auto_indent_buffer (project.guanako_project, current_source_file);
//     current_source_file.content = indented;
//     source_viewer.current_srcbuffer.text = indented;
// }

/**
 * Load file and change focus.
 *
 * @param filename Name of file.
 * @param focus `true` to focus item.
 * @return Return `true` on success else `false`.
 */
static bool on_file_selected (string filename, bool focus = true) {
    if (source_viewer.current_srcfocus == filename ||
            (!focus && source_viewer.get_sourceview_by_file (filename) != null))
        return true;

    string txt = "";
    try {
        FileUtils.get_contents (filename, out txt);
        var view = project.open_new_buffer (txt, filename);
        if (view != null)
            source_viewer.add_srcitem (view, filename);
        if (focus)
            source_viewer.focus_src (filename);
        source_viewer.jump_to_position (filename, 0, 0, true, focus);
        return true;
    } catch (GLib.FileError e) {
        errmsg (_("Could not load file: %s\n"), e.message);
        return false;
    }
}


public class GuanakoCompletion : Gtk.SourceCompletionProvider, Object {
    Gdk.Pixbuf icon;
    public string name;
    public int priority;
    GLib.List<Gtk.SourceCompletionItem> proposals;

    construct {
        Gdk.Pixbuf icon = this.get_icon();

        this.proposals = new GLib.List<Gtk.SourceCompletionItem>();
    }

    public string get_name() {
        return this.name;
    }

    public int get_priority() {
        return this.priority;
    }

    public bool match (Gtk.SourceCompletionContext context) {
        return true;
    }

    Project.CompletionRun completion_run = null;
    bool completion_run_queued = false;
    SuperSourceView.LineAnnotation current_symbol_annotation = null;
    TextMark completion_mark; /* The mark at which the proposals were generated */
    public void populate (Gtk.SourceCompletionContext context) {
        //TODO: Provide way to get completion for not saved content.
        if (is_new_document (source_viewer.current_srcfocus))
            return;

        lock (completion_run) {
            completion_run_queued = true;
            if (completion_run != null) {
                completion_run.abort_run();
                return;
            }
            completion_run = new Project.CompletionRun (project.guanako_project);
        }
        try {
            new Thread<void*>.try (_("Completion"), () => {
                /* Get completion proposals from Guanako */
                while (true) {
                    completion_run = new Project.CompletionRun (project.guanako_project);

                    /* Get current line */
                    completion_mark = source_viewer.current_srcbuffer.get_insert();
                    TextIter iter;
                    source_viewer.current_srcbuffer.get_iter_at_mark (out iter, completion_mark);
                    var line = iter.get_line() + 1;
                    var col = iter.get_line_offset();

                    TextIter iter_start;
                    source_viewer.current_srcbuffer.get_iter_at_line (out iter_start, line - 1);
                    var current_line = source_viewer.current_srcbuffer.get_text (iter_start, iter, false);

                    completion_run_queued = false;
                    if (current_line.strip() == "" && !source_viewer.current_srcbuffer.last_key_valid) {
                        if (context is SourceCompletionContext)
                            context.add_proposals (this, new GLib.List<Gtk.SourceCompletionItem>(), true);
                        current_symbol_annotation = null;
                        if (!completion_run_queued) {
                            completion_run = null;
                            break;
                        } else
                            continue;
                    }

                    var guanako_proposals = completion_run.run (project.guanako_project.get_source_file_by_name (source_viewer.current_srcfocus),
                                        line, col, current_line);
                    lock (completion_run) {
                        if (guanako_proposals == null) {
                            if (!completion_run_queued) {
                                completion_run = null;
                                break;
                            } else
                                continue;
                        }
                    }
                    Symbol current_symbol = null;
                    if (completion_run.cur_stack.size > 0)
                        current_symbol = completion_run.cur_stack.last();
                    else
                        current_symbol = null;
                    if (current_symbol_annotation != null)
                        current_symbol_annotation.finished = true;

                    if (current_symbol != null) {
                        string lblstr = "";
                        if (current_symbol is Method) {
                            var mth = current_symbol as Method;
                            if (mth.return_type.data_type != null)
                                lblstr += mth.return_type.data_type.name;
                            else
                                lblstr += "void";
                            lblstr += " " + mth.name + " (";
                            var prms = mth.get_parameters();
                            for (int q = 0; q < prms.size; q++) {
                                if (prms[q].direction == ParameterDirection.OUT)
                                    lblstr += "out ";
                                else if (prms[q].direction == ParameterDirection.REF)
                                    lblstr += "ref ";
                                lblstr += prms[q].variable_type.data_type.name + " " + prms[q].name;
                                if (q < prms.size - 1)
                                    lblstr += ", ";
                            }

                            lblstr += ")";
                        } else
                            lblstr = current_symbol.name;
                        current_symbol_annotation = source_viewer.current_srcview.annotate (line - 1, lblstr, 0.5, 0.5, 0.5, true, -1);
                    } else
                        current_symbol_annotation = null;
                    GLib.Idle.add (() => {
                        project.completion_finished (current_symbol);
                        return false;
                    });

                    /* Assign icons and pass the proposals on to Gtk.SourceView */
                    var props = new GLib.List<Gtk.SourceCompletionItem>();
                    foreach (FixedTreeSet<CompletionProposal> list in guanako_proposals)
                    foreach (CompletionProposal guanako_proposal in list) {
                        if (guanako_proposal.symbol.name != null) {

                            Gdk.Pixbuf pixbuf = get_pixbuf_for_symbol (guanako_proposal.symbol);

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
                    lock (completion_run) {
                        if (!completion_run_queued) {
                            completion_run = null;
                            break;
                        }
                    }
                }
                return null;
            });
        } catch (GLib.Error e) {
            errmsg (_("Could not launch completion thread successfully: %s\n"), e.message);
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

        /* Count backward from completion_mark instead of iter (avoids wrong insertion if the user is typing fast) */
        TextIter start;
        source_viewer.current_srcbuffer.get_iter_at_mark (out start, completion_mark);
        start.backward_chars (prop.replace_length);

        source_viewer.current_srcbuffer.delete (ref start, ref iter);
        source_viewer.current_srcbuffer.insert (ref start, prop.symbol.name, prop.symbol.name.length);
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
        var mark = source_viewer.current_srcbuffer.get_insert();
        TextIter cursor_iter;
        source_viewer.current_srcbuffer.get_iter_at_mark (out cursor_iter, mark);

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
