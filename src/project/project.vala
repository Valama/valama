/*
 * src/project/project.vala
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
using Gee;
using Gtk;
using Pango;

/**
 * IDE modes on which plugins can decide how to do some tasks.
 */
//TODO; Make this a plugin.
[Flags]
public enum IdeModes {
    DEBUG,
    RELEASE;

    /**
     * Number of modes.
     */
    const int size = 2;

    /**
     * Convert mode to string.
     *
     * @param mode {@link IdeModes} mode.
     * @return Return associated string or null.
     */
    public string? to_string() {
        switch (this) {
            case DEBUG:
                return _("Debug");
            case RELEASE:
                return _("Release");
            default:
                error_msg (_("Could not convert '%s' to string: %u\n"),
                           "IdeModes", this);
                return null;
        }
    }

    /**
     * Convert int to {@link IdeModes}.
     *
     * @param num Integer number.
     * @return Return corresponding mode or {@link IdeModes.DEBUG}.
     */
    public static IdeModes int_to_mode (int num) {
        int ret = 1;
        for (int i = 0; i < num; ++i)
            ret *= 2;
        return (IdeModes) ret;
    }

    /**
     * Convert {@link IdeModes} to int.
     */
    public static int to_int (IdeModes mode) {
        int ret = -1;
        int t = (int) mode;
        do {
            t >>= 1;
            ++ret;
        } while (t > 0);
        return ret;
    }

    /**
     * List of all enum values.
     */
    public static IdeModes[] values() {
        var ret = new IdeModes[0];
        for (int i = 0; i < size; ++i)
            ret += IdeModes.int_to_mode (i);
        return ret;
    }
}


/**
 * Valama project application.
 */
public class ValamaProject : RawValamaProject {
    /**
     * Attached Guanako project to provide code completion.
     */
    public Guanako.Project? guanako_project { get; private set; default = null; }
    /**
     * Identifier to provide context state to plugins.
     */
    public IdeModes idemode { get; set; default = IdeModes.DEBUG; }
    /**
     * Ordered list of all opened Buffers mapped with filenames.
     */
    //TODO: Do we need an __ordered__ list? Gtk has already focus handling.
    private LinkedList<ViewMap?> vieworder;
    /**
     * Completion provider.
     */
    private GuanakoCompletion comp_provider;

    /**
     * Emit when undo flag of current {@link SourceBuffer} has changed.
     *
     * @param undo_possibility True if undo is possible.
     */
    public signal void undo_changed (bool undo_possibility);
    /**
     * Emit when redo flag of current {@link SourceBuffer} has changed.
     *
     * @param redo_possibility True if redo is possible.
     */
    public signal void redo_changed (bool redo_possibility);

    /**
     * Emit signal if buffer has changed.
     *
     * @param has_changes True if buffer is dirty else false.
     */
    public signal void buffer_changed (bool has_changes);

    /**
     * Emit signal when Guanako update has started.
     */
    public signal void guanako_update_started();
    /**
     * Emit signal when Guanako update is finished.
     */
    public signal void guanako_update_finished();

    /**
     * Create {@link ValamaProject} and load it from project file.
     *
     * It is possible to fully load a partial loaded project with {@link init}.
     *
     * @param project_file Load project from this file.
     * @param syntaxfile Load Guanako syntax definitions from this file.
     * @param fully If false only load project file information.
     * @throws LoadingError Throw on error while loading project file.
     */
    public ValamaProject (string project_file,
                          string? syntaxfile = null,
                          bool fully = true) throws LoadingError {
        var proj_file = File.new_for_path (project_file);
        this.project_file = proj_file.get_path();
        project_path = proj_file.get_parent().get_path(); //TODO: Check valid path?

        if (fully)
            try {
                guanako_project = new Guanako.Project (syntaxfile);
            } catch (GLib.IOError e) {
                throw new LoadingError.COMPLETION_NOT_AVAILABLE (
                                        _("Could not read syntax file: %s\n"), e.message);
            } catch (GLib.Error e) {
                throw new LoadingError.COMPLETION_NOT_AVAILABLE (
                                        _("An error occured while loading new Guanako project: %s\n"),
                                        e.message);
            }

        packages = new TreeSet<PackageInfo?> ((CompareDataFunc<PackageInfo?>?) PackageInfo.compare_func);
        package_list = new TreeSet<string>();
        package_choices = new ArrayList<PkgChoice?>();
        source_dirs = new TreeSet<string>();
        source_files = new TreeSet<string>();
        buildsystem_dirs = new TreeSet<string>();
        buildsystem_files = new TreeSet<string>();

        msg (_("Load project file: %s\n"), this.project_file);
        load_project_file (this);  // can throw LoadingError

        if (fully)
            init (syntaxfile);
    }

    /**
     * Fully load project or do nothing when already fully loaded.
     *
     * @param syntaxfile Load Guanako syntax definitions from this file.
     * @throws LoadingError Throw if Guanako completion fails to load.
     */
    public void init (string? syntaxfile = null) throws LoadingError {
        if (guanako_project == null)
            try {
                guanako_project = new Guanako.Project (syntaxfile);
            } catch (GLib.IOError e) {
                throw new LoadingError.COMPLETION_NOT_AVAILABLE (
                                        _("Could not read syntax file: %s\n"), e.message);
            } catch (GLib.Error e) {
                throw new LoadingError.COMPLETION_NOT_AVAILABLE (
                                        _("An error occured while loading new Guanako project: %s\n"),
                                        e.message);
            }

        recentmgr.add_item (get_absolute_path (this.project_file));

        files = new TreeSet<string>();
        generate_file_list (source_dirs.to_array(),
                            source_files.to_array(),
                            add_source_file);

        b_files = new TreeSet<string>();
        generate_file_list (buildsystem_dirs.to_array(),
                            buildsystem_files.to_array(),
                            add_buildsystem_file);

        vieworder = new LinkedList<ViewMap?>();

        string[] missing_packages = guanako_project.add_packages (package_list.to_array(), false);

        if (missing_packages.length > 0)
            ui_missing_packages_dialog (missing_packages);

        /* Completion provider. */
        this.comp_provider = new GuanakoCompletion();
        this.comp_provider.priority = 1;
        this.comp_provider.name = _("%s - Vala").printf (project_name);
        this.notify["project-name"].connect (() => {
            comp_provider.name = _("%s - Vala").printf (project_name);
        });

        parsing = true;
        new Thread<void*> (_("Initial buffer update"), () => {
            guanako_project.update();
            Idle.add (() => {
                guanako_update_finished();
                parsing = false;
                return false;
            });
            return null;
        });
    }

    /**
     * Add sourcefile and register with Guanako.
     *
     * @param filename Absolute path to file.
     */
    public override void add_source_file (string filename) {
        if (!(filename.has_suffix (".vala") || filename.has_suffix (".vapi")))
            return;
        msg (_("Found file %s\n"), filename);
        if (this.files.add (filename))
            guanako_project.add_source_file_by_name (filename, filename.has_suffix (".vapi"));
        else
            debug_msg (_("Skip already added file: %s"), filename);
    }

    /**
     * Remove sourcefile from project and unlink from Guanako. Don't remove
     * file from disk. Keep track to not include it with source directories
     * next time.
     *
     * @param filename Absolute path to file to unregister.
     * @return Return true on success else false (e.g. if file was not found).
     */
    //TODO: Remove it also from .vlp file.
    public override bool remove_source_file (string filename) {
        if (!files.remove (filename))
            return false;
        guanako_project.remove_file (guanako_project.get_source_file_by_name (filename));
        return true;
    }

    /**
     * Open new buffer.
     *
     * If file was already loaded by project
     *
     * @param txt Containing text. Default is empty.
     * @param filename Filename to identify buffer. Default is empty.
     * @param dirty Flag if buffer is dirty. Default is false.
     * @return Return {@link Gtk.SourceView} if new buffer was created else null.
     */
    public SourceView? open_new_buffer (string txt = "", string filename = "", bool dirty = false) {
        debug_msg (_("Load new buffer: %s\n"),
                   (filename == "") ? _("(new file)")
                                    : get_absolute_path (filename));

        foreach (var viewelement in vieworder) {
            if (viewelement.filename == filename) {
                vieworder.remove (viewelement);
                vieworder.offer_head (viewelement);
                return null;
            }
        }

        var bfr = new SourceBuffer();
        var view = new SourceView.with_buffer (bfr);

        view.show_line_numbers = true;
        view.insert_spaces_instead_of_tabs = true;
        view.override_font (FontDescription.from_string ("Monospace 10"));
        view.auto_indent = true;
        view.indent_width = 4;

        bfr.begin_not_undoable_action();
        bfr.text = txt;
        bfr.end_not_undoable_action();

        bfr.highlight_matching_brackets = true;

        /* Undo manager. */
        var undoman = bfr.get_undo_manager();
        undoman.can_undo_changed.connect (() => {
            undo_changed (undoman.can_undo());
        });
        undoman.can_redo_changed.connect (() => {
            redo_changed (undoman.can_redo());
        });

        /* Syntax highlighting. */
        bfr.set_highlight_syntax (true);
        var langman = new SourceLanguageManager();
        SourceLanguage lang;
        if (filename == "")
            lang = langman.get_language ("vala");
        else if (Path.get_basename (filename) == "CMakeLists.txt")
            lang = langman.get_language ("cmake");
        else
            lang = langman.guess_language (filename, null);

        if (lang != null) {
            bfr.set_language (lang);

            if (bfr.language.id == "vala")
                try {
                    view.completion.add_provider (this.comp_provider);
                } catch (GLib.Error e) {
                    errmsg (_("Could not load completion: %s\n"), e.message);
                }
        }

        /* Modified flag. */
        bfr.notify["dirty"].connect (() => {
            this.buffer_changed (bfr.dirty);
        });
        bfr.dirty = dirty;

        bfr.changed.connect (() => {
            bfr.dirty = true;

            /* Don't try to update non-source files. */
            if (!(filename in files))
                return;

            bfr.needs_guanako_update = true;

            /* Update after timeout */
            if (bfr.timeout_id != -1)
                Source.remove (bfr.timeout_id);
            bfr.timeout_id = Timeout.add (1000, () => {
                if (bfr.needs_guanako_update) {
                    if (parsing) //If we are already parsing, try again next time
                        return true;
                    update_guanako (bfr);
                }
                bfr.timeout_id = -1;
                return false;
            });

            /* Immediate update after switching to a new line */
            if (!parsing) {
                var mark = source_viewer.current_srcbuffer.get_insert();
                TextIter iter;
                source_viewer.current_srcbuffer.get_iter_at_mark (out iter, mark);
                var line = iter.get_line() + 1;
                if (bfr.last_active_line == line)
                    return;
                bfr.last_active_line = line;
                update_guanako (bfr);
            }
        });

        var vmap = new ViewMap (view, filename);
        vieworder.offer_head (vmap);
        debug_msg (_("Buffer loaded.\n"));
        return view;
    }

    /**
     * Update Guanako completion proposals for buffer and run update for
     * current sourcefocus.
     *
     * @param buffer {@link Gtk.SourceBuffer} to look for completions.
     */
    private void update_guanako (SourceBuffer buffer) {
        parsing = true;
        buffer.needs_guanako_update = false;
        try {
            /* Get a copy of the buffer that is safe to work on
             * Otherwise, the thread might crash accessing it
             */
            string buffer_content =  buffer.text;
            new Thread<void*>.try (_("Buffer update"), () => {
                guanako_update_started();
                var source_file = this.guanako_project.get_source_file_by_name (
                                                source_viewer.current_srcfocus);
                this.guanako_project.update_file (source_file, buffer_content);
                Idle.add (() => {
                    guanako_update_finished();
                    parsing = false;
                    if (loop_update.is_running())
                        loop_update.quit();
                    return false;
                });
                return null;
            });
        } catch (GLib.Error e) {
            errmsg (_("Could not create thread to update buffer completion: %s\n"), e.message);
        }
    }

    /**
     * Save all opened project files.
     *
     * @return Return true on success else false.
     */
    public bool buffer_save_all() {
        bool ret = true;
        foreach (var map in vieworder) {
            if (map.filename == "")
                continue;
            var srcbuf = (SourceBuffer) map.view.buffer;
            srcbuf.dirty = !save_file (map.filename, srcbuf.text);
            if (ret && srcbuf.dirty)
                ret = false;
        }
        return  ret;
    }

    /**
     * Save specific project file and update dirty flag.
     *
     * @param filename Filename of buffer to save. If empty current buffer is
     *                 choosed. If filename is relative project path is
     *                 prepended.
     * @return Return true on success else false.
     */
    public bool buffer_save (string filename = "") {
        /* Use temporary variable to work arround unowned var issue. */
        string filepath = filename;
        if (filepath == "") {
            if (source_viewer.current_srcfocus == null) {
                warning_msg (_("No file selected.\n"));
                return false;
            }
            filepath = source_viewer.current_srcfocus;
        } else
            filepath = get_absolute_path (filepath);
        foreach (var map in vieworder)
            if (map.filename == filepath) {
                var srcbuf = (SourceBuffer) map.view.buffer;
                srcbuf.dirty = !save_file (map.filename, srcbuf.text);
                return !srcbuf.dirty;
            }
        warning_msg (_("Couldn't save project file: %s\n"), filename);
        return false;
    }

    /**
     * Check if buffer is dirty.
     *
     * @param filename Buffer by filename to check.
     * @return Return negated dirty flag of buffer or false if buffer doesn't
     *         exist in project file context.
     */
    public bool buffer_is_dirty (string filename) {
        foreach (var map in vieworder)
            if (map.filename == filename) {
                var srcbuf = (SourceBuffer) map.view.buffer;
                return srcbuf.dirty;
            }
        warning_msg (_("File not registered in project to check if buffer is dirty: %s\n"), filename);
        return false;
    }

    /**
     * Show dialog if {@link Gtk.SourceView} wasn't saved yet.
     *
     * @param view {@link Gtk.SourceView} to check if closing is ok.
     * @return Return true to indicate buffer can now closed safely.
     */
    public bool close_buffer (SourceView view) {
        /*
         * TODO: Not Implemented.
         *       Check if view.buffer is dirty. If so -> dialog
         */
        return false;
    }

    /**
     * Hold filename -> view/dirty mappings for {@link vieworder}.
     */
    private class ViewMap : Object {
        public ViewMap (SourceView view, string filename) {
            this.view = view;
            this.filename = filename;
        }

        public SourceView view;
        public string filename;
        /**
         * Use unique id to support multiple views for same file.
         */
        // private static int size = 0;
        // public int id = size++;
    }

    /**
     * Get {@link SourceBuffer} by file name.
     *
     * @param filename Filename to get buffer from.
     * @return Return {@link SourceBuffer} on success else null.
     */
    public SourceBuffer? get_buffer_by_file (string filename) {
        foreach (var map in vieworder)
            if (map.filename == filename)
                return (SourceBuffer) map.view.buffer;
        return null;
    }

    /**
     * Provide delegate to perform action on opened views. See
     * {@link foreach_buffer}.
     *
     * @param filename Filename of currently processed buffer.
     * @param buffertext Content of currently processed buffer.
     */
    public delegate void ViewCallback (string filename, SourceBuffer buffer);
    /**
     * Perform {@link ViewCallback} action for each opened
     * {@link Gtk.SourceView}.
     *
     * @param action Action to perform on each opened buffer.
     */
    public void foreach_buffer (ViewCallback action) {
        foreach (var map in vieworder)
            action (map.filename, (SourceBuffer) map.view.buffer);
    }
}

/**
* Add dirty flag to {@link Gtk.SourceBuffer}.
*/
public class SourceBuffer : Gtk.SourceBuffer {
    /**
     * Manually indicate if buffer has unsaved changes.
     */
    //TODO: Look at is_modified.
    public bool dirty { get; set; default = false; }
    public int last_active_line = -1;
    public bool needs_guanako_update = false;
    public uint timeout_id = -1;
}

// vim: set ai ts=4 sts=4 et sw=4
