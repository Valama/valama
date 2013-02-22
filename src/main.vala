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
static MainWidget widget_main;
static RecentManager recentmgr;
static WelcomeScreen? vscreen = null;

public static int main (string[] args) {
    Intl.textdomain (Config.GETTEXT_PACKAGE);
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    recentmgr = (RecentManager) GLib.Object.new (typeof(RecentManager),
            filename: Path.build_path (Path.DIR_SEPARATOR_S,
                                       Environment.get_user_cache_dir(),
                                       "valama",
                                       "recent_projects"));

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

    loop_update = new MainLoop();

    if (Args.projectfiles.length > 0)
        try {
            project = new ValamaProject (Args.projectfiles[0], Args.syntaxfile);
        } catch (LoadingError e) {
            errmsg (_("Couldn't load Valama project: %s\n"), e.message);
            project = null;
        }

    load_icons();

    window_main = new Window();
    window_main.destroy.connect (main_quit);
    window_main.title = _("Valama");
    window_main.hide_titlebar_when_maximized = true;
    window_main.set_default_size (1200, 600);
    window_main.maximize();

    window_main.show();

    if (project != null) {
        show_main_screen (project);
    } else {
        vscreen = new WelcomeScreen();
        window_main.add (vscreen);
        vscreen.project_loaded.connect (show_main_screen);
    }

    Gtk.main();

    project.save();
    return 0;
}

static void show_main_screen (ValamaProject load_project) {
    if (vscreen != null)
        vscreen.destroy();

    project = load_project;
    widget_main = new MainWidget();
    window_main.add (widget_main);
    window_main.add_accel_group (widget_main.accel_group);

    /* Application signals. */
    source_viewer.buffer_close.connect (project.close_buffer);

    source_viewer.notify["current-srcbuffer"].connect (() => {
        var srcbuf = source_viewer.current_srcbuffer;
        project.undo_changed (srcbuf.can_undo);
        project.redo_changed (srcbuf.can_redo);
        if (source_viewer.current_srcfocus != _("New document"))
            project.buffer_changed (project.buffer_is_dirty (
                                            source_viewer.current_srcfocus));
        else
            project.buffer_changed (true);
    });
}

static void load_icons() {
    map_icons = new Gee.HashMap<string, Gdk.Pixbuf>();
    foreach (string type in new string[] {"class",
                                          "class-private",
                                          "class-public",
                                          "constant",
                                          "constant-private",
                                          "constant-public",
                                          "delegate",
                                          "delegate-private",
                                          "delegate-protected",
                                          "delegate-public",
                                          "enum",
                                          "enum-private",
                                          "enum-public",
                                          "enum_value",
                                          "error_code",
                                          "error_code-private",
                                          "error_code-public",
                                          "error_domain",
                                          "error_domain-private",
                                          "error_domain-public",
                                          "field",
                                          "field-private",
                                          "field-public",
                                          "interface",
                                          "interface-private",
                                          "interface-protected",
                                          "interface-public",
                                          "method",
                                          "method-private",
                                          "method-protected",
                                          "method-public",
                                          "namespace",
                                          "property",
                                          "property-private",
                                          "property-protected",
                                          "property-public",
                                          "signal",
                                          "struct",
                                          "struct-private",
                                          "struct-public"})
    try {
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

static Gdk.Pixbuf? get_pixbuf_for_symbol (Symbol symbol) {
    if (symbol is Class)        return map_icons["class"];
    if (symbol is Constant)     return map_icons["constant"];
    if (symbol is Delegate)     return map_icons["delegate"];
    if (symbol is Enum)         return map_icons["enum"];
    if (symbol is Vala.EnumValue) return map_icons["enum_value"];
    if (symbol is ErrorCode)    return map_icons["error_code"];
    if (symbol is ErrorDomain)  return map_icons["error_domain"];
    if (symbol is Variable)     return map_icons["field"];
    if (symbol is Interface)    return map_icons["interface"];
    if (symbol is Method)       return map_icons["method"];
    if (symbol is Namespace)    return map_icons["namespace"];
    if (symbol is Property)     return map_icons["property"];
    if (symbol is Vala.Signal)  return map_icons["signal"];
    if (symbol is Struct)       return map_icons["struct"];
    return null;
}

static Gdk.Pixbuf? get_pixbuf_by_name (string typename) {
    if (typename in map_icons)
        return map_icons[typename];
    return null;
}

static void create_new_file() {
    var source_file = ui_create_file_dialog (project);
    if (source_file != null) {
        project.guanako_project.add_source_file (source_file);
        source_viewer.focus_src (source_file.filename);
        pbrw.update();
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

// static void on_auto_indent_button_clicked() {
//     string indented = Guanako.auto_indent_buffer (project.guanako_project, current_source_file);
//     current_source_file.content = indented;
//     source_viewer.current_srcbuffer.text = indented;
// }

static void on_file_selected (string filename) {
    if (source_viewer.current_srcfocus == filename)
        return;

    string txt = "";
    try {
        FileUtils.get_contents (filename, out txt);
        var view = project.open_new_buffer (txt, filename);
        if (view != null)
            source_viewer.add_srcitem (view, filename);
        source_viewer.focus_src (filename);
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

    public void populate (Gtk.SourceCompletionContext context) {
        //TODO: Provide way to get completion for not saved content.
        if (source_viewer.current_srcfocus == _("New document"))
            return;

        /* Get current line */
        var mark = source_viewer.current_srcbuffer.get_insert();
        TextIter iter;
        source_viewer.current_srcbuffer.get_iter_at_mark (out iter, mark);
        var line = iter.get_line() + 1;
        var col = iter.get_line_offset();

        TextIter iter_start;
        source_viewer.current_srcbuffer.get_iter_at_line (out iter_start, line - 1);
        var current_line = source_viewer.current_srcbuffer.get_text (iter_start, iter, false);

        if (parsing)
            loop_update.run();

        try {
            new Thread<void*>.try (_("Completion"), () => {
                /* Get completion proposals from Guanako */
                var guanako_proposals = project.guanako_project.propose_symbols (
                            project.guanako_project.get_source_file_by_name (source_viewer.current_srcfocus),
                            line,
                            col,
                            current_line);

                /* Assign icons and pass the proposals on to Gtk.SourceView */
                var props = new GLib.List<Gtk.SourceCompletionItem>();
                foreach (Gee.TreeSet<CompletionProposal> list in guanako_proposals)
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
