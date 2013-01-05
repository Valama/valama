/*
 * src/project.vala
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

using Vala;
using GLib;
using Gee;
using Xml;
using Gtk;
using Pango; // fonts

public class ValamaProject {
    public Guanako.project guanako_project { get; private set; }
    public string project_path { get; private set; }
    public string project_file { get; private set; }
    public string[] project_source_dirs { get; private set; default = {"src"}; }
    public string[] project_file_types { get; private set; default = {".vala", ".vapi"}; }
    public int version_major;
    public int version_minor;
    public int version_patch;
    public string project_name = _("valama_project");

    public Gee.ArrayList<string> files { get; private set; }

    //TODO: Do we need an __ordered__ list? Gtk has already focus handling.
    private Gee.LinkedList<ViewMap?> vieworder;
    private TestProvider comp_provider;

    public ValamaProject (string project_file) throws LoadingError {
        var proj_file = File.new_for_path (project_file);
        this.project_file = proj_file.get_path();
        project_path = proj_file.get_parent().get_path();

        guanako_project = new Guanako.project();
        files = new Gee.ArrayList<string>();

        stdout.printf (_("Load project file: %s\n"), this.project_file);
        load_project_file();  // can throw LoadingError

        /*
         * Add file type files in source directory folders to the project.
         * Default file suffix is .vala and default source directory is src/.
         */
        try {
            File directory;
            FileEnumerator enumerator;
            FileInfo file_info;

            foreach (string source_dir in project_source_dirs) {
                directory = File.new_for_path (join_paths ({project_path, source_dir}));
                enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

                while ((file_info = enumerator.next_file()) != null) {
                    string file = join_paths ({project_path,
                                               source_dir,
                                               file_info.get_name()});

                    foreach (string suffix in project_file_types) {
                        if (file.has_suffix (suffix)){
                            stdout.printf (_("Found file %s\n"), file);
                            guanako_project.add_source_file_by_name (file);
                            this.files.add (file);
                            break;
                        }
                    }
                }
            }
            if (FileUtils.test (join_paths ({project_path, "vapi", "config.vapi"}),
                                            FileTest.EXISTS))
                guanako_project.add_source_file_by_name (join_paths ({project_path,
                                                                     "vapi",
                                                                     "config.vapi"}));
        } catch (GLib.Error e) {
            stderr.printf(_("Could not open file: %s\n"), e.message);
        }

        guanako_project.update();

        vieworder = new Gee.LinkedList<ViewMap?>();

        /* Completion provider. */
        this.comp_provider = new TestProvider();
        this.comp_provider.priority = 1;
        this.comp_provider.name = _("Test Provider 1");
    }

    public string build() {
        string ret;

        try {
            string pkg_list = "set(required_pkgs\n";
            foreach (string pkg in guanako_project.packages)
                pkg_list += pkg + "\n";
            pkg_list += ")";

            var file_stream = File.new_for_path (
                                    join_paths ({project_path,
                                                "cmake",
                                                "project.cmake"})).replace(null,
                                                                           false,
                                                                           FileCreateFlags.REPLACE_DESTINATION);
            var data_stream = new DataOutputStream (file_stream);
            data_stream.put_string ("set(project_name " + project_name + ")\n");
            data_stream.put_string (@"set($(project_name)_VERSION $version_major.$version_minor.$version_patch)\n");
            data_stream.put_string (pkg_list);
            data_stream.close();
        } catch (GLib.IOError e) {
            stderr.printf(_("Could not read file: %s\n"), e.message);
        } catch (GLib.Error e) {
            stderr.printf(_("Could not open file: %s\n"), e.message);
        }

        try {
            GLib.Process.spawn_command_line_sync("sh -c 'cd " + project_path +
                                                    " && mkdir -p build && cd build && cmake .. && make'",
                                                 null,
                                                 out ret);
        } catch (GLib.SpawnError e) {
            stderr.printf(_("Could not execute build process: %s\n"), e.message);
        }
        return ret;
    }

    void load_project_file() throws LoadingError {
        Xml.Doc* doc = Xml.Parser.parse_file (project_file);

        if (doc == null) {
            delete doc;
            throw new LoadingError.FILE_IS_GARBAGE (_("Cannot parse file."));
        }

        Xml.Node* root_node = doc->get_root_element();
        if (root_node == null) {
            delete doc;
            throw new LoadingError.FILE_IS_EMPTY (_("File does not contain enough information"));
        }

        var packages = new string[0];
        for (Xml.Node* i = root_node->children; i != null; i = i->next) {
            if (i->type != ElementType.ELEMENT_NODE)
                continue;
            if (i->name == "name")
                project_name = i->get_content();
            if (i->name == "packages")
                for (Xml.Node* p = i->children; p != null; p = p->next)
                    if (p->name == "package")
                        packages += p->get_content();
            if (i->name == "version")
                for (Xml.Node* p = i->children; p != null; p = p->next) {
                    if (p->name == "major")
                        version_major = int.parse (p->get_content());
                    else if (p->name == "minor")
                        version_minor = int.parse (p->get_content());
                    else if (p->name == "patch")
                        version_patch = int.parse (p->get_content());
                }
        }
        string[] missing_packages = guanako_project.add_packages (packages, false);

        if (missing_packages.length > 0)
            ui_missing_packages_dialog(missing_packages);

        delete doc;
    }

    public void save() {
        var writer = new TextWriter.filename (project_file);
        writer.set_indent (true);
        writer.set_indent_string ("\t");

        writer.start_element ("project");
        writer.write_element ("name", project_name);

        writer.start_element ("version");
        writer.write_element ("major", version_major.to_string());
        writer.write_element ("minor", version_minor.to_string());
        writer.write_element ("patch", version_patch.to_string());
        writer.end_element();

        writer.start_element ("packages");
        foreach (string pkg in guanako_project.packages)
            writer.write_element ("package", pkg);
        writer.end_element();
        writer.end_element();
    }

    public SourceView? open_new_buffer (string txt = "", string filename = "") {
#if DEBUG
        string dbgstr;
        if (filename == "")
            dbgstr = _("(new file)");
        else
            dbgstr = filename;
        stdout.printf (_("Load new buffer: %s\n"), dbgstr);
#endif
        SourceView? view = null;
        foreach (var viewelement in vieworder) {
            if (viewelement.filename == filename) {
                vieworder.remove (viewelement);
                vieworder.offer_head (viewelement);
                return null;
            }
        }

        view = new SourceView();
        view.show_line_numbers = true;
        view.insert_spaces_instead_of_tabs = true;
        view.override_font (FontDescription.from_string ("Monospace 10"));
        view.buffer.create_tag ("gray_bg", "background", "gray", null);
        view.auto_indent = true;
        view.indent_width = 4;

        view.buffer.text = txt;

        var bfr = (SourceBuffer) view.buffer;
        bfr.set_highlight_syntax (true);
        var langman = new SourceLanguageManager();
        SourceLanguage lang;
        if (filename == "")
            lang = langman.get_language ("vala");
        else
            lang = langman.guess_language (filename, null);
        bfr.set_language (lang);

        if (bfr.language.id == "vala")
            try {
                view.completion.add_provider (this.comp_provider);
            } catch (GLib.Error e) {
                stderr.printf (_("Could not load completion: %s\n"), e.message);
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
                        var source_file = new SourceFile (project.guanako_project.context,
                                                          SourceFileType.SOURCE,
                                                          window_main.current_srcfocus);
                        project.guanako_project.update_file (source_file, view.buffer.text);
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
                    stderr.printf (_("Could not create thread to update buffer completion: %s\n"), e.message);
                }
            }
        });

        var vmap = new ViewMap (view, filename);
        vieworder.offer_head (vmap);
#if DEBUG
        stdout.printf (_("Buffer loaded.\n"));
#endif
        return view;
    }

    /**
     * Show dialog if {@link Gtk.SourceView} wasn't saved yet.
     *
     * Return true to close buffer.
     */
    public bool close_buffer (SourceView view) {
        /*
         * TODO: Not Implemented.
         *       Check if view.buffer is dirty. If so -> dialog
         */
        return false;
    }

    /**
     * Hold filename -> view mappings for {@link vieworder}.
     */
    private class ViewMap {
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
}

errordomain LoadingError {
    FILE_IS_EMPTY,
    FILE_IS_GARBAGE
}

// vim: set ai ts=4 sts=4 et sw=4
