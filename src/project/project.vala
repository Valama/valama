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
using Gtk;
using Pango;
using Xml;

/**
 * IDE modes on which plug-ins can decide how to do some tasks.
 */
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
     * @return Return associated string (locale dependent) or null.
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
     * Convert mode to string.
     *
     * @param mode {@link IdeModes} mode.
     * @return Return associated string (locale independent) or null.
     */
    public static string? to_string_int (IdeModes mode) {
        switch (mode) {
            case DEBUG:
                return "Debug";
            case RELEASE:
                return "Release";
            default:
                error_msg (_("Could not convert '%s' to string: %u\n"),
                           "IdeModes", mode);
                return null;
        }
    }

    /**
     * Convert string to mode.
     *
     * @param modename Name of mode (locale independent).
     */
    public static IdeModes? from_string (string modename) {
        switch (modename) {
            case "Debug":
                return DEBUG;
            case "Release":
                return RELEASE;
            default:
                error_msg (_("Could not convert '%s' to '%s'.\n"),
                           modename, "IdeModes");
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
public class ValamaProject : ProjectFile {
    /**
     * Attached Guanako project to provide code completion.
     */
    public Guanako.Project? guanako_project { get; private set; default = null; }

    /**
     * Attached build system.
     */
    public BuildSystem? builder { get; set; default = null; }

    /**
     * Identifier to provide context state to plug-ins.
     */
    public IdeModes idemode { get; set; default = IdeModes.DEBUG; }

    /**
     * Flag to show multiple files are added and an update on each new file
     * is not necessary. Set this manually.
     */
    public bool add_multiple_files { get; set; default = false; }

    /**
     * Ordered list of all opened Buffers mapped with filenames.
     */
    //TODO: Do we need an __ordered__ list? Gtk has already focus handling.
    private Gee.LinkedList<ViewMap?> vieworder;
    /**
     * Completion provider.
     */
    public GuanakoCompletion comp_provider { get; private set; }

    /**
     * All used defines in project.
     *
     * Use {@link set_define} or {@link unset_define} to add or remove define.
     */
    public TreeSet<string> defines { get; private set; }

    /**
     * List of available defines with file names where defines occur.
     */
    public TreeMap<string, TreeSet<string>> used_defines { get; private set; }

    /**
     * Checked but not enabled defines.
     *
     * Use {@link disable_define} or {@link enable_define} to disable or
     * enable avaibility of defines.
     */
    public TreeSet<string> disabled_defines { get; private set; }

    /**
     * Emit signal when source file was added or removed.
     */
    public signal void source_files_changed();
    /**
     * Emit signal when user interface file was added or removed.
     */
    public signal void ui_files_changed();
    /**
     * Emit signal when build system file was added or removed.
     */
    public signal void buildsystem_files_changed();
    /**
     * Emit signal when data file was added or removed.
     */
    public signal void data_files_changed();
    /**
     * Emit signal when package was added or removed.
     */
    public signal void packages_changed();
    /**
     * Emit signal when define was added or removed.
     *
     * @param added `true` if define was added, `false` if removed.
     * @param define Name of changed define.
     */
    public signal void defines_changed (bool added, string define);
    /**
     * Handler id for initial define update signal.
     */
    private ulong define_handler_id;
    /**
     * Emit to run update for changed defines.
     */
    private signal void defines_update();
    /**
     * Emit to set define (if found is `true`).
     *
     * NOTE: Currently don't disable defines to avoid (unnecessary) complete
     * source file update.
     *
     * @param define Processed define.
     * @param found `true` to set define (`false` to don't set it).
     * @return `true` on success else `false`.
     */
    //TODO: Return value needed?
    public signal bool define_set (string define, bool found = true);


    /**
     * Create {@link ValamaProject} and load it from project file.
     *
     * It is possible to fully load a partial loaded project with {@link init}.
     *
     * @param project_file Load project from this file.
     * @param syntaxfile Load Guanako syntax definitions from this file.
     * @param fully If `false` only load project file information.
     * @param save_recent Update recent project files catalogue.
     * @throws LoadingError Throw on error while loading project file.
     */
    internal ValamaProject.empty(string project_file) throws LoadingError
    {
		base.empty(project_file);
		constructor_init (null, true, false);
	} 
    
    public ValamaProject (string project_file,
                          string? syntaxfile = null,
                          bool fully = true,
                          bool save_recent = true) throws LoadingError {
        try {
            base (project_file);
        } catch (LoadingError e) {
            errmsg (_("Error loading project file '%s': %s\n"), project_file, e.message);
            throw e;
        }

        constructor_init (syntaxfile, fully, save_recent);
    }

    /**
     * Create {@link ValamaProject} and load it from project file.
     *
     * It is possible to fully load a partial loaded project with {@link init}.
     *
     * @param project_file_data Load project from data.
     * @param syntaxfile Load Guanako syntax definitions from this file.
     * @param fully If `false` only load project file information.
     * @param save_recent Update recent project files catalogue.
     * @throws LoadingError Throw on error while loading project file.
     */
    public ValamaProject.from_data (string project_file_data,
                                    string? syntaxfile = null,
                                    bool fully = true,
                                    bool save_recent = true) throws LoadingError {
        try {
            base.from_data (project_file_data);
        } catch (LoadingError e) {
            errmsg (_("Error loading project file from data: %s\n"), e.message);
            throw e;
        }

        constructor_init (syntaxfile, fully, save_recent);
    }

    private void constructor_init (string? syntaxfile, bool fully, bool save_recent) throws LoadingError {
        add_builder (buildsystem, library);

        if (fully)
            try {                       //TODO: Allow changing glib version.
                guanako_project = new Guanako.Project (syntaxfile, 2, 32);
            } catch (GLib.IOError e) {
                throw new LoadingError.COMPLETION_NOT_AVAILABLE (
                                        _("Could not read syntax file: %s\n"), e.message);
            } catch (GLib.Error e) {
                throw new LoadingError.COMPLETION_NOT_AVAILABLE (
                                        _("An error occurred while loading new Guanako project: %s\n"),
                                        e.message);
            }

        defines = new TreeSet<string>();
        used_defines = new TreeMap<string, TreeSet<string>>();
        disabled_defines = new TreeSet<string>();

        foreach (var pkg in packages.values)
            add_package (pkg, true);
        add_multiple_files = true;
        foreach (var choice in package_choices) {
            var pkg = get_choice (choice);
            if (pkg != null)
                add_package (pkg);
            else {
                warning_msg (_("Could not select a package from choice.\n"));
                add_package (choice.packages[0]);
            }
        }
        add_multiple_files = false;

        if (fully)
            init (syntaxfile, save_recent);
    }

    /**
     * Fully load project or do nothing when already fully loaded.
     *
     * @param syntaxfile Load Guanako syntax definitions from this file.
     * @param save_recent Update recent project files catalogue.
     * @throws LoadingError Throw if Guanako completion fails to load.
     */
    public void init (string? syntaxfile = null, bool save_recent = true) throws LoadingError {
        try {
            load_meta();
        } catch (LoadingError e) {
            warning_msg (_("Could not load meta information: %s\n"), e.message);
        }
        if (guanako_project == null)
            try {
                guanako_project = new Guanako.Project (syntaxfile);
            } catch (GLib.IOError e) {
                throw new LoadingError.COMPLETION_NOT_AVAILABLE (
                                        _("Could not read syntax file: %s\n"), e.message);
            } catch (GLib.Error e) {
                throw new LoadingError.COMPLETION_NOT_AVAILABLE (
                                        _("An error occurred while loading new Guanako project: %s\n"),
                                        e.message);
            }

        if (save_recent)
            save_to_recent();
        if (builder != null)
            try {
                builder.init (this);
            } catch (BuildError e) {
                bug_msg (_("Could not initialize build system: %s\n"), e.message);
            }

        generate_file_list (ref _source_dirs,
                            ref _source_files,
                            add_source_file);

        generate_file_list (ref _ui_dirs,
                            ref _ui_files,
                            add_ui_file);

        generate_file_list (ref _buildsystem_dirs,
                            ref _buildsystem_files,
                            add_buildsystem_file);

        generate_file_list (ref _data_dirs,
                            ref _data_files,
                            add_data_file);

        vieworder = new Gee.LinkedList<ViewMap?>();

        var extrapkgs = new TreeSet<PackageInfo>();
        var normpkgs = new TreeSet<string>();
        foreach (var pkg in packages.values)
            if ((pkg.custom_vapi != null) || (pkg.nodeps != null && pkg.nodeps))
                extrapkgs.add (pkg);
            else
                normpkgs.add (pkg.name);

        var missings = new TreeSet<string>();

        foreach (var pkg in extrapkgs) {
            if (pkg.custom_vapi != null) {
                //NOTE: !pkg.nodeps results to error see #700985.
                if (pkg.nodeps == null || pkg.nodeps == false) {
                    var depsfile = Guanako.get_deps_path (
                                    Path.get_basename (pkg.custom_vapi.substring (
                                                       0,
                                                       pkg.custom_vapi.length - 5)),
                                    new string[] { Path.get_dirname (
                                                        get_absolute_path (pkg.custom_vapi))
                                                 });
                    if (depsfile != null) {
                        debug_msg (_("Dependency file found: %s\n"), depsfile);
                        try {
                            string contents;
                            FileUtils.get_contents (depsfile, out contents);
                            foreach (var pkgname in contents.split ("\n")) {
                                pkgname = pkgname.strip();
                                if (pkgname != "")
                                    normpkgs.add (pkgname);
                            }
                        } catch (FileError e) {
                            warning_msg (_("Unable to read dependency file: %s\n"), e.message);
                            break;
                        }
                    } else
                        debug_msg (_("No dependency file (.deps) for package '%s' found.\n"),
                                   pkg.name);
                }
                if (guanako_project.add_source_file_by_name (get_absolute_path (pkg.custom_vapi), true) == null) {
                    missings.add (pkg.custom_vapi);
                    warning_msg (_("Could not add custom vapi for %s: %s\n"),
                                 pkg.name, pkg.custom_vapi);
                } else
                    normpkgs.remove (pkg.name);
            } else if (pkg.nodeps != null && pkg.nodeps) {
                var vapifile = guanako_project.get_context_vapi_path (pkg.name);
                if (vapifile == null || guanako_project.add_source_file_by_name (vapifile, true) == null) {
                    missings.add (pkg.name);
                    warning_msg (_("Could not add custom vapi for %s: %s\n"),
                                 pkg.name, pkg.custom_vapi);
                } else
                    normpkgs.remove (pkg.name);
            } else
                bug_msg (_("Unknown situation: %s\n"), "project.vala - extrapkgs");
        }

        var missing_packages = guanako_project.add_packages (normpkgs.to_array(), false);
        foreach (var pkg in missing_packages)
            missings.add (pkg);

        foreach (var pkg in packages.values)
            if (pkg.define != null && !(pkg.name in missings)) {
                defines.add (pkg.define);
                guanako_project.add_define (pkg.define);
            }
        guanako_project.commit_defines();

        packages_changed();

        if (missing_packages.length > 0)
            ui_missing_packages_dialog (missing_packages);

        /* Completion provider. */
        this.comp_provider = new GuanakoCompletion();
        this.comp_provider.priority = 1;
        this.comp_provider.name = _("%s - Vala").printf (project_name);
        this.notify["project-name"].connect (() => {
            comp_provider.name = _("%s - Vala").printf (project_name);
        });

        VoidDelegate? init_define_signals = null;
        guanako_update_finished.connect (() => {
            var used_defines_new = new TreeMap<string, TreeSet<string>>();
            var mit = guanako_project.get_defines_used().map_iterator();
            var new_defines = new TreeSet<string>();
            while (mit.next())
                foreach (var define in mit.get_value()) {
                    if (define in used_defines_new.keys)
                        used_defines_new[define].add (mit.get_key());
                    else {
                        var tset = new TreeSet<string>();
                        tset.add (mit.get_key());
                        used_defines_new[define] = tset;
                    }
                    if (!(define in defines))
                        new_defines.add (define);
                }
            used_defines = used_defines_new;

            if (init_define_signals == null) {
                init_define_signals = () => {
                    define_set.connect ((define, found) => {
                        if (found) {
                            if (set_define (define)) {
                                defines_update();
                                return true;
                            }
                        } /*else if (unset_define (define)) {
                            defines_update();
                            return true;
                        }*/ else {
                            unset_define (define);
                            disabled_defines.add (define);
                            return true;
                        }
                        return false;
                    });
                    defines_update.connect (() => {
                        parsing = true;
                        try {
                            new Thread<void*>.try (_("Source file update"), () => {
                                guanako_update_started();
                                guanako_project.update();
                                Idle.add (() => {
                                    guanako_update_finished();
                                    parsing = false;
                                    return false;
                                });
                                return null;
                            });
                        } catch (GLib.Error e) {
                            errmsg (_("Could not create thread to update source files: %s\n"), e.message);
                            parsing = false;
                        }
                    });
                };

                var initial_defines = new TreeSet<string>();
                initial_defines.add_all (new_defines);
                if (initial_defines.size > 0) {
                    define_handler_id = define_set.connect ((define, found) => {
                        var ret = initial_defines.remove (define);
                        if (found)
                            set_define (define);
                        else
                            disable_define (define);
                        if (initial_defines.size == 0) {
                            this.disconnect (define_handler_id);
                            init_define_signals();
                            defines_update();
                        }
                        return ret;
                    });
                    foreach (var define_new in new_defines)
                        defines_changed (true, define_new);
                } else
                    init_define_signals();
            } else {
                var removals = new TreeSet<string>();
                foreach (var define in defines)
                    if (!(define in used_defines.keys))
                        removals.add (define);
                foreach (var define in removals) {
                    defines.remove (define);
                    defines_changed (false, define);
                }

                foreach (var define in new_defines)
                    defines_changed (true, define);
            }
        });

        parsing = true;
        new Thread<void*> (_("Initial buffer update"), () => {
            guanako_project.init();
            Idle.add (() => {
                guanako_update_finished();
                parsing = false;
                return false;
            });
            return null;
        });
    }

    private delegate void VoidDelegate();

    /**
     * Update list of recent projects.
     */
    public inline void save_to_recent() {
        debug_msg_level (3, _("Add project to recent manager: %s - %s\n"), project_name, project_file_path);
        if (!recentmgr.add_full (Posix.realpath (project_file_path) ?? project_file_path,
                                 RecentData() { display_name = project_name,
                                                mime_type = "application/octet-stream",
                                                app_name = "Valama",  //TODO: Translatable?
                                                app_exec = "valama %u"}))
            warning_msg (_("Could not add project to recent manager.\n"));
    }

    /**
     * Add package to project. Remember to add it later to Guanako project and
     * emit packages_changed signal.
     *
     * @param pkg Package to add.
     * @param upgrade If `true` upgrade pkg with new values.
     */
    public void add_package (PackageInfo pkg, bool upgrade = false) {
        var included = pkg.name in packages.keys;
        if (!upgrade && included) {
            debug_msg_level (2, _("Package '%s' already included. Skip it.\n"), pkg.name);
            return;
        }

        var info = pkg.to_string_full();
        if (pkg.choice != null)
            // TRANSLATORS: Choice of different packages.
            info += " (%s)".printf (_("choice"));
        debug_msg_level (2, _("Add package: %s\n"), info);
        if (pkg.extrachecks != null) {
            foreach (var check in pkg.extrachecks) {
                string? custom_vapi = null;
                var custom_defines = new TreeSet<string>();
                if (check.check (this, ref custom_vapi, ref custom_defines)) {
                    var strb = new StringBuilder();
                    var space = false;
                    if (custom_vapi != null) {
                        pkg.custom_vapi = custom_vapi;
                        pkg.save_vapi = false;
                        strb.append ("vapi: %s".printf (custom_vapi));
                        space = true;
                    }
                    if (space)
                        strb.append (", ");
                    if (custom_defines.size == 1)
                        strb.append (_("define:"));
                    else if (custom_defines.size > 1)
                        strb.append (_("defines:"));
                    foreach (var define in custom_defines) {
                        defines.add (define);
                        guanako_project.add_define (define);
                        defines_changed (true, define);
                        strb.append (@" $define");
                    }
                    if (strb.str != "")
                        debug_msg_level (2, _("PkgCheck succeeded: %s\n"), strb.str);
                    break;
                }
            }
        }

        if (!included)
            packages[pkg.name] = pkg;
    }

    /**
     * Add package to project by package name and update Guanako project.
     *
     * @param pkgs Packages to add.
     * @return Not available packages or `null` if all packages were previously added.
     */
    public string[]? add_packages_by_names (string[] pkgs) {
        var newpkgs = new string[0];
        foreach(string pkg in pkgs) {
            if (!(pkg in packages.keys)) {
                var pkginfo = new PackageInfo();
                pkginfo.name = pkg;
                packages[pkg] = pkginfo;
                newpkgs += pkg;
                debug_msg_level (2, _("Add package: %s\n"), pkg);
            } else
                debug_msg_level (2, _("Add package: %s (already added)\n"), pkg);
        }
        if (newpkgs.length > 0) {
            packages_changed();
            return guanako_project.add_packages (newpkgs, true);
        } else
            return null;
    }

    /**
     * Remove package from project. Remember to update Guanako project and
     * emit packages_changed signal.
     *
     * @param pkg Package to remove.
     * @return `false` if package not in project else `true`.
     */
    public bool remove_package (PackageInfo pkg) {
        debug_msg_level (2, _("Remove package: %s\n"), pkg.to_string());
        if (!packages.unset (pkg.name)) {
            debug_msg (_("Package '%s' not in list, skip it.\n"), pkg.name);
            return false;
        }
        if (pkg.choice != null && !pkg.choice.remove_package (pkg))
            package_choices.remove (pkg.choice);
        return true;
    }

    /**
     * Remove package from project and update Guanako project.
     *
     * @param pkg Package name.
     * @return `false` if package not in project else `true`.
     */
    public bool remove_package_by_name (string pkg) {
        debug_msg_level (2, _("Remove package: %s\n"), pkg);
        if (!(pkg in packages.keys)) {
            debug_msg (_("Package '%s' not in list, skip it.\n"), pkg);
            return false;
        }

        var pkginfo = packages[pkg];
        if (pkginfo.choice != null && !pkginfo.choice.remove_package (pkginfo))
            package_choices.remove (pkginfo.choice);
        packages.unset (pkg);

        guanako_project.remove_package (pkg);
        packages_changed();
        return true;
    }

    /**
     * Get list of all used packages (not only manually added ones).
     *
     * @return Package list.
     */
    public inline Vala.List<string> get_all_packages() {
        return guanako_project.get_context_packages();
    }

    /**
     * Get list of all errors after Guanako update.
     *
     * @return Return error list.
     */
    public inline Gee.ArrayList<Guanako.Reporter.Error> get_errorlist() {
        return guanako_project.get_errorlist();
    }

    /**
     * Add source file and register with Guanako.
     *
     * @param filename Path to file.
     * @param directory Add directory.
     */
    public void add_source_file (string? filename, bool directory = false) {
        if (filename == null || (!directory &&
                    !(filename.has_suffix (".vala") || filename.has_suffix (".vapi"))))
            return;
        var filename_abs = get_absolute_path (filename);

        var f = File.new_for_path (filename_abs);
        if (!f.query_exists()) {
            if (!directory)
                warning_msg (_("Source file does not exist: %s\n"), filename_abs);
            else
                warning_msg (_("Source directory does not exist: %s\n"), filename_abs);
            return;
        }

        if (directory) {
            source_dirs.add (filename);
            source_files_changed();
            return;
        }

        if (!filename.has_suffix(".vapi"))
            msg (_("Found source file: %s\n"), filename_abs);

        if (d_files.contains (filename_abs)) {
            warning_msg (_("File already a user interface file. Skip it.\n"), filename_abs);
            return;
        } else if (b_files.contains (filename_abs)) {
            warning_msg (_("File already registered for build system. Skip it.\n"), filename_abs);
            return;
        } else if (d_files.contains (filename_abs)) {
            warning_msg (_("File already a data file. Skip it.\n"), filename_abs);
            return;
        }
        if (!files.contains (filename_abs))
            if (guanako_project.add_source_file_by_name (
                                filename_abs, filename_abs.has_suffix (".vapi")) != null) {
                files.add (filename_abs);
                source_files_changed();
            } else
                warning_msg (_("Could not load Vala source file: %s\n"), filename_abs);
        else
            debug_msg (_("Skip already added file: %s\n"), filename_abs);
    }

    /**
     * Remove source file from project and unlink from Guanako. Don't remove
     * file from disk. Keep track to not include it with source directories
     * next time.
     *
     * Close buffer manually.
     *
     * @param filename Path to file to unregister.
     * @return `true` on success else `false` (e.g. if file was not found).
     */
    public bool remove_source_file (string? filename) {
        var filename_abs = get_absolute_path (filename);
        debug_msg (_("Remove source file: %s\n"), filename_abs);
        if (!files.remove (filename_abs))
            return false;
        new Thread<void*> (_("Remove source file"), () => {
            source_files_changed();
            guanako_project.remove_file (guanako_project.get_source_file_by_name (filename_abs));
            return null;
        });
        return true;
    }

    /**
     * Add file to user interface list.
     *
     * @param filename Path to file.
     * @param directory Add directory.
     */
    public void add_ui_file (string? filename, bool directory = false) {
        if (filename == null || (!directory &&
                !(filename.has_suffix (".ui") || filename.has_suffix (".glade") ||
                  filename.has_suffix (".xml"))))
            return;
        var filename_abs = get_absolute_path (filename);

        var f = File.new_for_path (filename_abs);
        if (!f.query_exists()) {
            if (!directory)
                warning_msg (_("User interface file does not exist: %s\n"), filename_abs);
            else
                warning_msg (_("User interface directory does not exist: %s\n"), filename_abs);
            return;
        }

        if (directory) {
            ui_dirs.add (filename);
            ui_files_changed();
            return;
        }

        msg (_("Found user interface file: %s\n"), filename_abs);
        if (files.contains (filename_abs)) {
            warning_msg (_("File already a source file. Skip it.\n"), filename_abs);
            return;
        } else if (b_files.contains (filename_abs)) {
            warning_msg (_("File already registered for build system. Skip it.\n"), filename_abs);
            return;
        } else if (d_files.contains (filename_abs)) {
            warning_msg (_("File already registered for build system. Skip it.\n"), filename_abs);
            return;
        }
        if (!this.u_files.add (filename_abs))
            debug_msg (_("Skip already added file: %s\n"), filename_abs);
        else
            ui_files_changed();
    }

    /**
     * Remove user interface file from project. Close buffer manually.
     *
     * @param filename Path to file to unregister.
     * @return `true` on success else `false` (e.g. if file was not found).
     */
    public bool remove_ui_file (string filename) {
        var filename_abs = get_absolute_path (filename);
        debug_msg (_("Remove user interface file: %s\n"), filename_abs);
        if (!u_files.remove (filename_abs))
            return false;
        ui_files_changed();
        return true;
    }

    /**
     * Add file to build system list.
     *
     * @param filename Path to file.
     * @param directory Add directory.
     */
    public void add_buildsystem_file (string? filename, bool directory = false) {
        if (builder == null || filename == null || (!directory &&
                    !builder.check_buildsystem_file (filename)))
            return;
        var filename_abs = get_absolute_path (filename);

        var f = File.new_for_path (filename_abs);
        if (!f.query_exists()) {
            if (!directory)
                warning_msg (_("Build system file does not exist: %s\n"), filename_abs);
            else
                warning_msg (_("Build system directory does not exist: %s\n"), filename_abs);
            return;
        }

        if (directory) {
            buildsystem_dirs.add (filename);
            buildsystem_files_changed();
            return;
        }

        msg (_("Found build system file: %s\n"), filename_abs);
        if (files.contains (filename_abs)) {
            warning_msg (_("File already a source file. Skip it.\n"), filename_abs);
            return;
        } else if (u_files.contains (filename_abs)) {
            warning_msg (_("File already a user interface file. Skip it.\n"), filename_abs);
            return;
        } else if (d_files.contains (filename_abs)) {
            warning_msg (_("File already a data file. Skip it.\n"), filename_abs);
            return;
        }
        if (!this.b_files.add (filename_abs))
            debug_msg (_("Skip already added file: %s\n"), filename_abs);
        else
            buildsystem_files_changed();
    }

    /**
     * Remove build system file from project. Close buffer manually.
     *
     * @param filename Path to file to unregister.
     * @return `true` on success else `false` (e.g. if file was not found).
     */
    public bool remove_buildsystem_file (string filename) {
        var filename_abs = get_absolute_path (filename);
        debug_msg (_("Remove build system file: %s\n"), filename_abs);
        if (!b_files.remove (filename_abs))
            return false;
        buildsystem_files_changed();
        return true;
    }

    /**
     * Add file to extra file list.
     *
     * @param filename Path to file.
     * @param directory Add directory.
     */
    public void add_data_file (string? filename, bool directory = false) {
        if (filename == null)
            return;
        var filename_abs = get_absolute_path (filename);

        var f = File.new_for_path (filename_abs);
        if (!f.query_exists()) {
            if (!directory)
                warning_msg (_("Data file does not exist: %s\n"), filename_abs);
            else
                warning_msg (_("Data directory does not exist: %s\n"), filename_abs);
            return;
        }

        if (directory) {
            data_dirs.add (filename);
            data_files_changed();
            return;
        }

        msg (_("Found data file: %s\n"), filename_abs);
        if (files.contains (filename_abs)) {
            warning_msg (_("File already a source file. Skip it.\n"), filename_abs);
            return;
        } else if (u_files.contains (filename_abs)) {
            warning_msg (_("File already a user interface file. Skip it.\n"), filename_abs);
            return;
        } else if (b_files.contains (filename_abs)) {
            warning_msg (_("File already registered for build system. Skip it.\n"), filename_abs);
            return;
        }
        if (!this.d_files.add (filename_abs))
            debug_msg (_("Skip already added file: %s\n"), filename_abs);
        else
            data_files_changed();
    }

    /**
     * Remove data file from project. Close buffer manually.
     *
     * @param filename Path to file to unregister.
     * @return `true` on success else `false` (e.g. if file was not found).
     */
    public bool remove_data_file (string filename) {
        var filename_abs = get_absolute_path (filename);
        debug_msg (_("Remove data file: %s\n"), filename_abs);
        if (!d_files.remove (filename_abs))
            return false;
        data_files_changed();
        return true;
    }

    /**
     * Close buffer by file name.
     *
     * @param filename Name of file to close view object.
     */
    public void close_viewbuffer (string filename) {
        ViewMap? vmap = null;
        foreach (var map in vieworder) {
            if (map.filename == get_absolute_path (filename)) {
                vmap = map;
                break;
            }
        }
        if (vmap != null)
            vieworder.remove (vmap);
        else
            // TRANSLATORS:
            // Context: "Could not close source view (mapping) for: myfile.vala"
            warning_msg (_("Could not close source view (mapping) for: %s\n"),
                         filename);
    }

    /**
     * Callback to perform action with valid file.
     *
     * @param filename Absolute path to existing file.
     * @param directory Add directory (not used).
     */
    public delegate void FileCallback (string filename, bool directory = false);
    /**
     * Iterate over directories and files and fill list.
     *
     * Check for file existence.
     *
     * @param dirlist List of directories.
     * @param filelist List of files.
     * @param action Method to perform on each found file in directory or
     *               file list.
     * @param checkfile Check file existence.
     * @param checkdir Check directory existence.
     */
    public void generate_file_list (ref TreeSet<string> dirlist,
                                    ref TreeSet<string> filelist,
                                    FileCallback? action = null,
                                    bool checkfile = true,
                                    bool checkdir = false) {
        File directory;
        FileEnumerator enumerator;
        FileInfo file_info;

        TreeSet<string> removals = null;
        if (checkfile || checkdir)
            removals = new TreeSet<string>();

        foreach (var dir in dirlist) {
            if (!FileUtils.test (dir, FileTest.IS_DIR)) {
                if (checkdir) {
                    warning_msg (_("No such directory: %s\n"), dir);
                    removals.add (dir);
                } else {
                    debug_msg (_("No such directory: %s\n"), dir);
                    continue;
                }
            }
            try {
                directory = File.new_for_path (dir);
                enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

                while ((file_info = enumerator.next_file()) != null) {
                    if (file_info.get_file_type() != FileType.REGULAR)  //TODO: Follow symlinks.
                        continue;
                    action (Path.build_path (Path.DIR_SEPARATOR_S,
                                             dir,
                                             file_info.get_name()));
                }
            } catch (GLib.Error e) {
                errmsg (_("Could not open directory '%s': %s\n"), dir, e.message);
                removals.add (dir);
            }
        }
        if (checkdir) {
            foreach (var dir in removals)
                dirlist.remove (dir);
            removals.clear();
        }

        foreach (var filename in filelist) {
            var f = File.new_for_path (filename);
            switch (f.query_file_type (FileQueryInfoFlags.NONE)) {
                case FileType.REGULAR:
                    action (filename);
                    break;
                default:
                    if (checkfile) {
                        warning_msg (_("No valid file: %s\n"), filename);
                        removals.add (filename);
                    } else
                        debug_msg (_("No valid file: %s\n"), filename);
                    break;
            }
        }
        if (checkfile)
            foreach (var file in removals)
                filelist.remove (file);
    }

    private void save_meta() {
        var path = Path.build_path (Path.DIR_SEPARATOR_S,
                                    Environment.get_user_cache_dir(),
                                    "valama",
                                    "project_meta.xml");
        debug_msg (_("Save project meta information: %s\n"), path);
        var writer = new TextWriter.filename (path);
        writer.set_indent (true);
        writer.set_indent_string ("\t");

        //TODO: Meta file version.
        writer.start_element ("project-meta");
        //writer.write_attribute ("version", xXx);
        writer.write_element ("idemode", IdeModes.to_string_int (idemode));
        writer.end_element();
    }

    private void load_meta() throws LoadingError {
        var path = Path.build_path (Path.DIR_SEPARATOR_S,
                                    Environment.get_user_cache_dir(),
                                    "valama",
                                    "project_meta.xml");
        debug_msg (_("Load project meta information: %s\n"), path);

        Xml.Doc* doc = Xml.Parser.parse_file (path);

        if (doc == null) {
            delete doc;
            throw new LoadingError.FILE_IS_GARBAGE (_("Cannot parse file."));
        }

        Xml.Node* root_node = doc->get_root_element();
        if (root_node == null || root_node->name != "project-meta") {
            delete doc;
            throw new LoadingError.FILE_IS_EMPTY (_("File does not contain enough information."));
        }

        // if (root_node->has_prop ("version") != null)
        //     xXx = root_node->get_prop ("version");
        // if (comp_version (xXx, xXx_VERSION_MIN) < 0) {
        //     var errstr = _("Project file too old: %s < %s").printf (xXx,
        //                                                             xXx_VERSION_MIN);
        //     if (!Args.forceold) {
        //         throw new LoadingError.FILE_IS_OLD (errstr);
        //         delete doc;
        //     } else
        //         warning_msg (_("Ignore project file loading error: %s\n"), errstr);
        // }

        for (Xml.Node* i = root_node->children; i != null; i = i->next) {
            if (i->type != ElementType.ELEMENT_NODE)
                continue;
            switch (i->name) {
                case "idemode":
                    var mode = IdeModes.from_string (i->get_content());
                    if (mode != null)
                        idemode = mode;
                    else
                        warning_msg (_("Unknown attribute for '%s' line %hu: %s\n"),
                                       "idemode", i->line, i->get_content());
                    break;
                default:
                    warning_msg (_("Unknown configuration file value line %hu: %s\n"),
                                 i->line, i->name);
                    break;
            }
        }
    }

    public bool close (bool save_all = false) {
        save_meta();
        save_project_file();

        if (save_all)
            return buffer_save_all();

        var changed_files = new TreeSet<string>();
        foreach (var map in vieworder) {
            //TODO: Ask here too if dirty.
            if (map.filename == "")
                continue;
            if (((SourceBuffer) map.view.buffer).dirty)
                changed_files.add (map.filename);
        }
        if (changed_files.size > 0) {
            var fstr = "";
            foreach (var file in changed_files)
                fstr += @"$file\n";
            var ret = ui_ask_file (_("Following files are modified. Do you want to save them?"),
                                   Markup.escape_text (fstr));
            switch (ret) {
                case ResponseType.REJECT:
                    return true;
                case ResponseType.ACCEPT:
                    return buffer_save_all();
                case ResponseType.CANCEL:
                    return false;
                default:
                    bug_msg (_("Unexpected response value: %s - %u"),
                             "close - ValamaProject", ret);
                    return false;
            }
        } else
            return true;
    }

    /**
     * Load build system.
     */
    public bool add_builder (string? buildsystem, bool lib = false) {
        if (buildsystem == null) {
            builder = null;
            return true;
        }
        switch (buildsystem) {
            case "plain":
            case "valama":
                builder = new BuilderPlain();
                break;
            case "cmake":
                builder = new BuilderCMake(lib);
                break;
            case "autotools":
				builder = new BuilderAutotools(lib);
				break;
            default:
                warning_msg (_("Build system '%s' not supported.\n"), buildsystem);
                return false;
        }
        return  true;
    }

    /**
     * Select first available package of {@link PkgChoice}. Does not check for
     * conflicts.
     *
     * @param choice {@link PkgChoice} to search for available packages.
     * @return Return available package name or null.
     */
    //TODO: Check version.
    private PackageInfo? get_choice (PkgChoice choice) {
        if (guanako_project != null) {
            //TODO: Do this like init method in ProjectTemplate (check against all vapis).
            foreach (var pkg in choice.packages)
                if (guanako_project.get_context_vapi_path (pkg.name) != null) {
                    debug_msg (_("Choose '%s' package.\n"), pkg.name);
                    return pkg;
                } else
                    debug_msg (_("Skip '%s' choice.\n"), pkg.name);
        } else {
            //TODO: Do this like init method in ProjectTemplate (check against all vapis).
            foreach (var pkg in choice.packages)
                if (Guanako.get_vapi_path (pkg.name) != null) {
                    debug_msg (_("Choose '%s' package.\n"), pkg.name);
                    return pkg;
                } else
                    debug_msg (_("Skip '%s' choice.\n"), pkg.name);
        }
        return null;
    }

    /**
     * Enable define.
     *
     * @param define Define to enable.
     * @return `true` on success.
     */
    public inline bool set_define (string define) {
        if (used_defines.has_key (define)) {
            defines.add (define);
            if (guanako_project.add_define (define)) {
                defines_update();
                return true;
            }
        }
        return false;
    }

    /**
     * Disable define.
     *
     * @param define Define to enable.
     * @return `true` on success.
     */
    public inline bool unset_define (string define) {
        defines.remove (define);
        return guanako_project.remove_define (define);
    }

    /**
     * Mark define as not available (additionally disable it).
     *
     * @param define Define to enable.
     * @return `true` on success.
     */
    public inline bool disable_define (string define) {
        unset_define (define);
        return disabled_defines.add (define);
    }

    /**
     * Mark define as available again (don't disable it).
     *
     * @param define Define to enable.
     * @return `true` on success.
     */
    public inline bool enable_define (string define) {
        return disabled_defines.remove (define);
    }

    /**
     * Mark all (disabled) defines as available.
     */
    public inline void enable_defines_all() {
        disabled_defines.clear();
    }

    /**
     * Check if define is already enabled.
     *
     * @param define Name of define.
     * @return `true` if enabled else `false`.
     */
    public inline bool define_is_enabled (string define) {
        return (define in guanako_project.defines);
    }

    /**
     * Check if define is already enabled and if so emit define_set signal.
     *
     * @param define Name of define.
     * @return `true` if enabled else `false`.
     */
    public inline bool define_is_enabled_emit (string define) {
        if (define in guanako_project.defines) {
            define_set (define, true);
            return true;
        } else
            return false;
    }

    /**
     * Check if define is marked as not available.
     *
     * @param define Name of define.
     * @return `true` if ''not'' available.
     */
    public inline bool define_is_not_available (string define) {
        return (define in disabled_defines);
    }

    /**
     * Emit when undo flag of current {@link SourceBuffer} has changed.
     *
     * @param undo_possibility `true` if undo is possible.
     */
    public signal void undo_changed (bool undo_possibility);
    /**
     * Emit when redo flag of current {@link SourceBuffer} has changed.
     *
     * @param redo_possibility `true` if redo is possible.
     */
    public signal void redo_changed (bool redo_possibility);

    /**
     * Open new buffer.
     *
     * If file was already loaded by project
     *
     * @param txt Containing text. Default is empty.
     * @param filename Filename to identify buffer. Default is empty.
     * @param dirty Flag if buffer is dirty. Default is `false`.
     * @return Return {@link Gtk.SourceView} if new buffer was created else null.
     */
    public SuperSourceView? open_new_buffer (string txt = "", string filename = "", bool dirty = false) {
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
        if (filename != "")
            files_opened.add (filename);

        var bfr = new SourceBuffer();
        var view = new SuperSourceView (bfr);
        view.key_press_event.connect ((key)=>{
            bfr.last_key_valid = !(key.keyval == Gdk.Key.space || key.keyval == Gdk.Key.Delete
                                   || key.keyval == Gdk.Key.Tab || key.keyval == Gdk.Key.BackSpace
                                   || key.keyval == 123 || key.keyval == 125 //Curly brackets
                                   || key.keyval == Gdk.Key.semicolon || key.keyval == 65293); // That's Enter
            return false;
        });

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
        else {
            var basename = Path.get_basename (filename);
            lang = langman.guess_language (basename, ContentType.guess (basename, null, null));
        }

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
        });

        /*
         * NOTE: Remember to connect completion proposals when file was added
         *       later to project source files.
         */
        if (/*bfr.language.id == "vala" &&*/ filename in files)
            bfr.changed.connect (() => {
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
     * current source file focus.
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
                    return false;
                });
                return null;
            });
        } catch (GLib.Error e) {
            errmsg (_("Could not create thread to update buffer: %s\n"), e.message);
            parsing = false;
        }
    }

    /**
     * Emit signal if buffer has changed.
     *
     * @param has_changes `true` if buffer is dirty else `false`.
     */
    public signal void buffer_changed (bool has_changes);

    /**
     * Emit signal when Guanako update is finished.
     */
    public signal void guanako_update_finished();

    /**
     * Emit signal when Guanako update has started.
     */
    public signal void guanako_update_started();

    public signal void completion_finished (Vala.Symbol? current_symbol);

    /**
     * Save all opened project files.
     *
     * @return Return `true` on success else `false`.
     */
    public bool buffer_save_all() {
        bool ret = true;
        foreach (var map in vieworder) {
            //TOOD: Ask here too if dirty.
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
     *                 chosen. If filename is relative project path is
     *                 prepended.
     * @return Return `true` on success else `false`.
     */
    public bool buffer_save (string filename = "") {
        /* Use temporary variable to work around unowned var issue. */
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
     * @return Return negated dirty flag of buffer or `false` if buffer does
     *         not exist in project file context.
     */
    public bool buffer_is_dirty (string filename) {
        foreach (var map in vieworder)
            if (map.filename == filename) {
                var srcbuf = (SourceBuffer) map.view.buffer;
                return srcbuf.dirty;
            }
        // TRANSLATORS:
        // File has to be registered with Valama (loaded) to check if the
        // buffer was modified.
        warning_msg (_("File not registered in project to check if buffer is dirty: %s\n"),
                     filename);
        return false;
    }

    /**
     * Show dialog if {@link Gtk.SourceView} wasn't saved yet.
     *
     * @param view {@link Gtk.SourceView} to check if closing is ok.
     * @param filename Name of file to close.
     * @return Return `true` to indicate buffer can now closed safely.
     */
    public bool close_buffer (SourceView view, string? filename) {
        var bfr = (SourceBuffer) view.buffer;
        if (bfr.dirty) {
            var ret = ui_ask_file (_("File is modified. Do you want to save it?"),
                                   Markup.escape_text (filename));
            switch (ret) {
                case ResponseType.REJECT:
                    files_opened.remove (filename);
                    return true;
                case ResponseType.ACCEPT:
                    files_opened.remove (filename);
                    return buffer_save (filename);
                case ResponseType.CANCEL:
                    return false;
                default:
                    bug_msg (_("Unexpected response value: %s - %u"),
                             "close_buffer - ValamaProject", ret);
                    return false;
            }
        }
        debug_msg (_("Close buffer.\n"));
        return true;
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
     * @param buffer Currently processed buffer.
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
    public bool last_key_valid = false;
}

// vim: set ai ts=4 sts=4 et sw=4
