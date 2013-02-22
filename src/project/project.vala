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

using Vala;
using GLib;
using Gee;
using Xml;
using Gtk;
using Pango;

/**
 * Current compatible version of project file.
 */
const string VLP_VERSION_MIN = "0.1";

/**
 * IDE modes on which plugins can decide how to do some tasks.
 */
public enum IdeModes {
    DEBUG   = 0,
    RELEASE = 1
}


/**
 * Valama project application.
 */
public class ValamaProject : Object {
    /**
     * Attached Guanako project to provide code completion.
     */
    public Guanako.Project guanako_project { get; private set; }

    private string _project_path;
    /**
     * Absolute path to project root.
     */
    public string project_path {
        get {
            return _project_path;
        }
        private set {
            _project_path = value;
            project_path_file = File.new_for_path (value);
        }
    }

    /**
     * Project path file object.
     */
    public File project_path_file { get; private set; }
    /**
     * Absolute path to project file.
     */
    public string project_file { get; private set; }
    /**
     * Project source directories (absolute paths).
     */
    public string[] project_source_dirs { get; private set; }
    /**
     * Project extra source files (absolute paths).
     */
    public string[] project_source_files { get; private set; }
    /**
     * Project buildsystem directories (absolute paths).
     */
    public string[] project_buildsystem_dirs { get; private set; }
    /**
     * Project extra buildsystem files (absolute paths).
     */
    public string[] project_buildsystem_files { get; private set; }
    /**
     * Project version first part.
     */
    public int version_major { get; set; default = 0; }
    /**
     * Project version second part.
     */
    public int version_minor { get; set; default = 0; }
    /**
     * Project version third part.
     */
    public int version_patch { get; set; default = 0; }
    /**
     * Name of project.
     */
    public string project_name { get; set; default = _("valama_project"); }
    /**
     * Version of .vlp file
     */
    public string project_file_version { get; private set; default = "0"; }
    /**
     * Identifier to provide context state to plugins.
     */
    public IdeModes idemode { get; set; default = IdeModes.DEBUG; }

    /**
     * List of source files.
     */
    public Gee.TreeSet<string> files { get; private set; }
    /**
     * List of buildsystem files.
     */
    public Gee.TreeSet<string> b_files { get; private set; }

    /**
     * Ordered list of all opened Buffers mapped with filenames.
     */
    //TODO: Do we need an __ordered__ list? Gtk has already focus handling.
    private Gee.LinkedList<ViewMap?> vieworder;
    /**
     * Completion provider.
     */
    private TestProvider comp_provider;

    /**
     * The project's buildsystem (valama/cmake/...).
     */
    public string buildsystem = "cmake";


    /**
     * Create {@link ValamaProject} and load it from project file.
     *
     * @param project_file Load project from this file.
     * @param syntaxfile Load Guanako syntax definitions from this file.
     * @throws LoadingError Throw on error while loading project file.
     */
    public ValamaProject (string project_file, string? syntaxfile = null) throws LoadingError {
        recentmgr.add_item (project_file);

        var proj_file = File.new_for_path (project_file);
        this.project_file = proj_file.get_path();
        project_path = proj_file.get_parent().get_path(); //TODO: Check valid path?

        try {
            guanako_project = new Guanako.Project (syntaxfile);
        } catch (GLib.IOError e) {
            stderr.printf (_("Could not read syntax file: %s"), e.message);
            Gtk.main_quit();
        } catch (GLib.Error e) {
            stderr.printf (_("An error occured: %s"), e.message);
            Gtk.main_quit();
        }

        files = new Gee.TreeSet<string>();
        b_files = new Gee.TreeSet<string>();

        msg (_("Load project file: %s\n"), this.project_file);
        load_project_file();  // can throw LoadingError

        generate_file_list (project_source_dirs,
                            project_source_files,
                            add_source_file);
        generate_file_list (project_buildsystem_dirs,
                            project_buildsystem_files,
                            add_buildsystem_file);

        guanako_project.update();

        vieworder = new Gee.LinkedList<ViewMap?>();

        /* Completion provider. */
        this.comp_provider = new TestProvider();
        this.comp_provider.priority = 1;
        this.comp_provider.name = _("Test Provider 1");
    }

    /**
     * Add sourcefile and register with Guanako.
     *
     * @param filename Absolute path to file.
     */
    private void add_source_file (string filename) {
        if (!(filename.has_suffix (".vala") || filename.has_suffix (".vapi")))
            return;
        msg (_("Found file %s\n"), filename);
        if (this.files.add (filename))
            guanako_project.add_source_file_by_name (filename);
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
    public bool remove_source_file (string filename) {
        if (!files.remove (filename))
            return false;
        guanako_project.remove_file (guanako_project.get_source_file_by_name (filename));
        return true;
    }

    /**
     * Add file to buildsystem list.
     *
     * @param filename Path to file.
     */
    private void add_buildsystem_file (string filename) {
        if (!(filename.has_suffix (".cmake") || Path.get_basename (filename) == ("CMakeLists.txt")))
            return;
        msg (_("Found file %s\n"), filename);
        if (!this.b_files.add (filename))
            debug_msg (_("Skip already added file: %s"), filename);
    }

    /**
     * Callback to perform action with valid file.
     *
     * @param filename Absolute path to existing file.
     */
    private delegate void FileCallback (string filename);
    /**
     * Iterate over directories and files and fill list.
     *
     * @param dirlist List of directories.
     * @param filelist List of files.
     * @param action Method to perform on each found file in directory or
     *               file list.
     */
    private void generate_file_list (string[] dirlist,
                                     string[] filelist,
                                     FileCallback? action = null) {
        try {
            File directory;
            FileEnumerator enumerator;
            FileInfo file_info;

            foreach (string dir in dirlist) {
                directory = File.new_for_path (dir);
                enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

                while ((file_info = enumerator.next_file()) != null) {
                    action (Path.build_path (Path.DIR_SEPARATOR_S,
                                             dir,
                                             file_info.get_name()));
                }
            }

            foreach (string filename in filelist) {
                var file = File.new_for_path (filename);
                if (file.query_exists())
                    action (filename);
                else
                    warning_msg (_("File not found: %s\n"), filename);
            }
        } catch (GLib.Error e) {
            errmsg (_("Could not open file: %s\n"), e.message);
        }

    }

    /**
     * Load Valama project from .vlp (xml) file.
     *
     * @throws LoadingError Throw if file to load contains errors. E.g. it
     *                      does not exist or does not contain enough
     *                      information.
     */
    private void load_project_file() throws LoadingError {
        Xml.Doc* doc = Xml.Parser.parse_file (project_file);

        if (doc == null) {
            delete doc;
            throw new LoadingError.FILE_IS_GARBAGE (_("Cannot parse file."));
        }

        Xml.Node* root_node = doc->get_root_element();
        if (root_node == null || root_node->name != "project") {
            delete doc;
            throw new LoadingError.FILE_IS_EMPTY (_("File does not contain enough information."));
        }

        if (root_node->has_prop ("version") != null)
            project_file_version = root_node->get_prop ("version");
        if (comp_proj_version (project_file_version, VLP_VERSION_MIN) < 0) {
            delete doc;
            throw new LoadingError.FILE_IS_OLD (_("Project file to old: %s < %s"),
                                                project_file_version,
                                                VLP_VERSION_MIN);
        }

        var packages = new string[0];
        var source_dirs = new string[0];
        var source_files = new string[0];
        var buildsystem_dirs = new string[0];
        var buildsystem_files = new string[0];
        for (Xml.Node* i = root_node->children; i != null; i = i->next) {
            if (i->type != ElementType.ELEMENT_NODE)
                continue;
            switch (i->name) {
                case "name":
                    project_name = i->get_content();
                    break;
                case "buildsystem":
                    buildsystem = i->get_content();
                    break;
                case "packages":
                    for (Xml.Node* p = i->children; p != null; p = p->next)
                        if (p->name == "package")
                            packages += p->get_content();
                    break;
                case "version":
                    for (Xml.Node* p = i->children; p != null; p = p->next) {
                        if (p->name == "major")
                            version_major = int.parse (p->get_content());
                        else if (p->name == "minor")
                            version_minor = int.parse (p->get_content());
                        else if (p->name == "patch")
                            version_patch = int.parse (p->get_content());
                    }
                    break;
                case "source-directories":
                    for (Xml.Node* p = i-> children; p != null; p = p->next)
                        if (p->name == "directory")
                            source_dirs += get_absolute_path (p->get_content());
                    break;
                case "source-files":
                    for (Xml.Node* p = i-> children; p != null; p = p->next)
                        if (p->name == "file")
                            source_files += get_absolute_path (p->get_content());
                    break;
                case "buildsystem-directories":
                    for (Xml.Node* p = i-> children; p != null; p = p->next)
                        if (p->name == "directory")
                            buildsystem_dirs += get_absolute_path (p->get_content());
                    break;
                case "buildsystem-files":
                    for (Xml.Node* p = i-> children; p != null; p = p->next)
                        if (p->name == "file")
                            buildsystem_files += get_absolute_path (p->get_content());
                    break;
                default:
                    errmsg ("Warning: Unknown configuration file value: %s", i->name);
                    break;
            }
        }
        string[] missing_packages = guanako_project.add_packages (packages, false);
        project_source_dirs = source_dirs;
        project_source_files = source_files;
        project_buildsystem_dirs = buildsystem_dirs;
        project_buildsystem_files = buildsystem_files;

        if (missing_packages.length > 0)
            ui_missing_packages_dialog (missing_packages);

        delete doc;
    }

    /**
     * Save project to {@link project_file}.
     */
    public void save() {
        var writer = new TextWriter.filename (project_file);
        writer.set_indent (true);
        writer.set_indent_string ("\t");

        writer.start_element ("project");
        writer.write_attribute ("version", project_file_version);
        writer.write_element ("name", project_name);
        writer.write_element ("buildsystem", buildsystem);

        writer.start_element ("version");
        writer.write_element ("major", version_major.to_string());
        writer.write_element ("minor", version_minor.to_string());
        writer.write_element ("patch", version_patch.to_string());
        writer.end_element();

        writer.start_element ("packages");
        foreach (string pkg in guanako_project.packages)
            writer.write_element ("package", pkg);
        writer.end_element();

        writer.start_element ("source-directories");
        foreach (string directory in project_source_dirs)
            writer.write_element ("directory", get_relative_path (directory));
        writer.end_element();

        writer.start_element ("source-files");
        foreach (string directory in project_source_files)
            writer.write_element ("file", get_relative_path (directory));
        writer.end_element();

        writer.start_element ("buildsystem-directories");
        foreach (string directory in project_buildsystem_dirs)
            writer.write_element ("directory", get_relative_path (directory));
        writer.end_element();

        writer.start_element ("buildsystem-files");
        foreach (string directory in project_buildsystem_files)
            writer.write_element ("file", get_relative_path (directory));
        writer.end_element();

        writer.end_element();
    }

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
        bfr.notify["dirty"].connect ((sender, property) => {
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
                report_wrapper.clear();
                var source_file = this.guanako_project.get_source_file_by_name (
                                                source_viewer.current_srcfocus);
                this.guanako_project.update_file (source_file, buffer_content);
                Idle.add (() => {
                    wdg_report.update();
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
     * Emit signal if buffer has changed.
     *
     * @param has_changes True if buffer is dirty else false.
     */
    public signal void buffer_changed (bool has_changes);

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

    /**
     * Get absolute path to file.
     *
     * @param path Absolute path or path relative to project root directory.
     * @return Return absolute path to directory.
     */
    public string get_absolute_path (string path) {
        if (Path.is_absolute (path))
            return path;
        return Path.build_path (Path.DIR_SEPARATOR_S, project_path, path);
    }

    /**
     * Get relative path to project directory if file is in same directory
     * tree.
     *
     * @param path Absolute or relative path.
     * @return Return relative path to project root directory or absolute path
     *         if file is not in tree below project root.
     */
    public string get_relative_path (string path) {
        if (!Path.is_absolute (path))
            return path;
        if (path.has_prefix (project_path))  // only simple string comparison
            return project_path_file.get_relative_path (File.new_for_path (path));
        return path;
    }
}

/**
* Add dirty flag to {@link Gtk.SourceBuffer}.
*/
public class SourceBuffer : Gtk.SourceBuffer {
    /**
     * Manually indicate if buffer has unsaved changes.
     */
    public bool dirty { get; set; default = false; }
    public int last_active_line = -1;
    public bool needs_guanako_update = false;
    public uint timeout_id = -1;
}


/**
 * Throw on project file loading errors.
 */
errordomain LoadingError {
    /**
     * File content probably too old.
     */
    FILE_IS_OLD,
    /**
     * File does not contain enough information.
     */
    FILE_IS_EMPTY,
    /**
     * Unable to load file.
     */
    FILE_IS_GARBAGE
}

// vim: set ai ts=4 sts=4 et sw=4
