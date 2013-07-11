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
static ValamaSettings settings;

public static int main (string[] args) {
    Intl.textdomain (Config.GETTEXT_PACKAGE);
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    recentmgr = (RecentManager) GLib.Object.new (typeof(RecentManager),
            filename: Path.build_path (Path.DIR_SEPARATOR_S,
                                       Environment.get_user_cache_dir(),
                                       "valama",
                                       "recent_projects.xml"));

    settings = new ValamaSettings ();

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
    int sx, sy;
    window_main.get_size (out sx, out sy);
    settings.window_size_x = sx;
    settings.window_size_y = sy;

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
        Object (application_id: "app.valama", flags: GLib.ApplicationFlags.NON_UNIQUE);
    }

    public override void activate () {
        window_main = new ApplicationWindow(gtk_app);
        window_main.title = _("Valama");
        window_main.hide_titlebar_when_maximized = true;
        window_main.set_default_size (settings.window_size_x, settings.window_size_y);

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

    widget_main.request_close.connect (() => {
        widget_main.close();
        window_main.remove (widget_main);
        project = null;
        window_main.add (vscreen);
        widget_main = null;
    });

    /* Open default source files. */
    var focus = true;
    foreach (var file in project.files_opened) {
        on_file_selected (file, focus);
        focus = false;
    }

    /* Application signals. */
    source_viewer.init();
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
        var view = project.open_new_buffer ("", filename);
        if (view != null)
            source_viewer.add_srcitem (view, filename);
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

// vim: set ai ts=4 sts=4 et sw=4
