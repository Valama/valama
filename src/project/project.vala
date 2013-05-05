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
 * Version relations. Can be used e.g. for package or valac versions.
 */
public enum VersionRelation {
    SINCE,  // >=
    UNTIL,  // <=
    ONLY,   // ==
    EXCLUDE;// !=

    public string? to_string() {
        switch (this) {
            case SINCE:
                return _("since");
            case UNTIL:
                return _("until");
            case ONLY:
                return _("only");
            case EXCLUDE:
                return _("exclude");
            default:
                error_msg (_("Could not convert '%s' to string: %u\n"),
                           "VersionRelation", this);
                return null;
        }
    }
}

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
                error_msg (_("Could not convert '%s' to %s.\n"),
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
 * Vala package alternatives.
 */
public class PkgChoice {
    /**
     * Indicate if all packages should go to build system package list.
     */
    public bool all = false;
    /**
     * Ordered list of packages. Packages in the front have higher
     * priority.
     */
    public Gee.ArrayList<PackageInfo?> packages { get; private set; }
    /**
     * Optional description.
     */
    public string? description = null;

    public PkgChoice() {
        packages = new Gee.ArrayList<PackageInfo?>();
    }

    /**
     * Automatically add {@link PkgChoice} reference to each
     * {@link PackageInfo} object.
     *
     * @param pkg Package to add to package choices list.
     */
    public void add_package (PackageInfo pkg) {
        pkg.choice = this;
        packages.add (pkg);
    }

    /**
     * Remove {@link PackageInfo} object from choices list.
     *
     * @param pkg Package choice.
     * @return `false` if choices list is empty after operation, else `true`.
     */
    public bool remove_package (PackageInfo pkg) {
        packages.remove (pkg);
        if (packages.size == 0)
            return false;
        return true;
    }
}

/**
 * Vala package information.
 */
public class PackageInfo {
    /**
     * Reference to {@link PkgChoice} if any.
     *
     * Do not modify this value manually. It will result in undefined behaviour.
     */
    public virtual PkgChoice? choice { get; set; default = null; }
    /**
     * Version relation.
     */
    public virtual VersionRelation? rel { get; set; default = null; }
    /**
     * Package name.
     */
    public virtual string name { get; set; }
    /**
     * Version (meaning differs with {@link rel}).
     */
    public virtual string? version { get; set; default = null; }

    /**
     * Convert class object to string.
     */
    public string? to_string() {
        var relation = "";
        if (rel != null)
            switch (rel) {
                case VersionRelation.SINCE:
                    relation = " >= ";
                    break;
                case VersionRelation.UNTIL:
                    relation = " <= ";
                    break;
                case VersionRelation.ONLY:
                    relation = " = ";
                    break;
                case VersionRelation.EXCLUDE:
                    relation = " != ";
                    break;
                default:
                    bug_msg (_("Unexpected enum value: %s: %u\n"),
                             "PackageInfo - to_string", rel);
                    break;
            }
        if (version != null) {
            if (relation != "")
                relation += version;
            else
                relation = @" >= $version";
        }
        return name + relation;
    }

    /**
     * Compare {@link PackageInfo} objects.
     *
     * @param pkg1 First package.
     * @param pkg2 Second package.
     * @return Return > 0 if pkg1 > pkg2, < 0 if pkg1 < pkg2 or 0 if pkg1 == pkg2.
     */
    public static int compare_func (PackageInfo pkg1, PackageInfo pkg2) {
        int namerel = strcmp (pkg1.name, pkg2.name);
        if (namerel != 0)
            return namerel;

        int verrel = comp_version (pkg1.version, pkg2.version);
        if (verrel != 0)
            return verrel;

        if (pkg1.rel != null && pkg2.rel != null) {
            int relrel = pkg1.rel - pkg2.rel;
            if (relrel != 0)
                return relrel;
        } else if (pkg1.rel != null)
            return 1;
        else if (pkg2.rel != null)
            return -1;

        return 0;
    }
}


/**
 * Valama project application.
 */
public class ValamaProject : Object {
    /**
     * Attached Guanako project to provide code completion.
     */
    public Guanako.Project? guanako_project { get; private set; default = null; }

    /**
     * Attached build system.
     */
    public BuildSystem? builder { get; private set; default = null; }

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
     * List of package choices.
     */
    public Gee.ArrayList<PkgChoice?> package_choices { get; private set; }
    /**
     * Project source directories (absolute paths).
     */
    public TreeSet<string> source_dirs { get; private set; }
    /**
     * Project extra source files (absolute paths).
     */
    public TreeSet<string> source_files { get; private set; }
    /**
     * Project build system directories (absolute paths).
     */
    public TreeSet<string> buildsystem_dirs { get; private set; }
    /**
     * Project extra build system files (absolute paths).
     */
    public TreeSet<string> buildsystem_files { get; private set; }
    /**
     * Project directories for extra files (absolute paths).
     */
    public TreeSet<string> data_dirs { get; private set; }
    /**
     * Project extra files (absolute paths).
     */
    public TreeSet<string> data_files { get; private set; }
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
     * Identifier to provide context state to plug-ins.
     */
    public IdeModes idemode { get; set; default = IdeModes.DEBUG; }

    /**
     * List of source files.
     */
    public TreeSet<string> files { get; private set; }
    /**
     * List of build system files.
     */
    public TreeSet<string> b_files { get; private set; }
    /**
     * List of extra files.
     */
    public TreeSet<string> d_files { get; private set; }
    /**
     * Flag to show multiple files are added and an update on each new file
     * is not necessary. Set this manually.
     */
    public bool add_multiple_files { get; set; default = false; }

    /**
     * List of opened files.
     */
    //TODO: Support only for templates and not normal projects.
    public Gee.ArrayList<string> files_opened { get; private set; }

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
     * Required packages with version information.
     *
     * Use {@link add_package} or {@link add_package_by_name} to add a new
     * package.
     */
    public TreeMultiMap<string, PackageInfo?> packages { get; private set; }

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
     * Emit signal when source file was added or removed.
     */
    public signal void source_files_changed();
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
    public ValamaProject (string project_file,
                          string? syntaxfile = null,
                          bool fully = true,
                          bool save_recent = true) throws LoadingError {
        var proj_file = File.new_for_path (project_file);
        this.project_file = proj_file.get_path();
        project_path = proj_file.get_parent().get_path(); //TODO: Check valid path?

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

#if GEE_0_8
        packages = new TreeMultiMap<string, PackageInfo?> (null, (CompareDataFunc<PackageInfo?>?) PackageInfo.compare_func);
#elif GEE_1_0
        packages = new TreeMultiMap<string, PackageInfo?> (null, (CompareFunc?) PackageInfo.compare_func);
#endif
        package_choices = new Gee.ArrayList<PkgChoice?>();
        source_dirs = new TreeSet<string>();
        source_files = new TreeSet<string>();
        buildsystem_dirs = new TreeSet<string>();
        buildsystem_files = new TreeSet<string>();
        data_dirs = new TreeSet<string>();
        data_files = new TreeSet<string>();

        defines = new TreeSet<string>();
        used_defines = new TreeMap<string, TreeSet<string>>();

        files = new TreeSet<string>();
        b_files = new TreeSet<string>();
        d_files = new TreeSet<string>();

        files_opened = new Gee.ArrayList<string>();

        msg (_("Load project file: %s\n"), this.project_file);
        load_project_file();  // can throw LoadingError

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

        generate_file_list (_source_dirs.to_array(),
                            _source_files.to_array(),
                            add_source_file);

        generate_file_list (_buildsystem_dirs.to_array(),
                            _buildsystem_files.to_array(),
                            add_buildsystem_file);

        generate_file_list (_data_dirs.to_array(),
                            _data_files.to_array(),
                            add_data_file);

        vieworder = new Gee.LinkedList<ViewMap?>();

        string[] missing_packages = guanako_project.add_packages (packages.get_keys().to_array(), false);
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
            while (mit.next()) {
                foreach (var define in mit.get_value())
                    if (define in used_defines_new.keys)
                        used_defines_new[define].add (mit.get_key());
                    else {
                        var tset = new TreeSet<string>();
                        tset.add (mit.get_key());
                        used_defines_new[define] = tset;
                    }
            }
            used_defines = used_defines_new;

            var removals = new TreeSet<string>();
            foreach (var define in defines)
                if (!(define in used_defines.keys))
                    removals.add (define);
            foreach (var define in removals) {
                defines.remove (define);
                defines_changed (false, define);
            }

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
                        }*/
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
                initial_defines.add_all (used_defines.keys);
                if (initial_defines.size > 0)
                    define_handler_id = define_set.connect ((define, found) => {
                        var ret = initial_defines.remove (define);
                        if (found)
                            set_define (define);
                        if (initial_defines.size == 0) {
                            this.disconnect (define_handler_id);
                            init_define_signals();
                            defines_update();
                        }
                        return ret;
                    });
                else
                    init_define_signals();
            }

            foreach (var define in used_defines.keys)
                if (defines.add (define))
                    defines_changed (true, define);
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
        debug_msg_level (3, _("Add project to recent manager: %s - %s\n"), project_name, project_file);
        if (!recentmgr.add_full (project_file,
                                 RecentData() { display_name = project_name,
                                                mime_type = "application/octet-stream",
                                                app_name = "Valama",  //TODO: Translatable?
                                                app_exec = "valama %u"}))
            warning_msg (_("Could not add project to recent manager.\n"));
    }

    /**
     * Reduce length of file list: Prefer directories and remove directories
     * without content.
     *
     * @param c_dirs Directories.
     * @param c_files Files.
     ( @param extensions Valid file extensions.
     */
    private void balance_dir_file_sets (ref TreeSet<string> c_dirs,
                                        ref TreeSet<string> c_files,
                                        string[]? extensions = null,
                                        string[]? filenames = null) {
        var new_c_dirs = new TreeSet<string>();
        var visited_bad = new TreeSet<string>();
        var new_c_files = new TreeSet<string>();

        foreach (var filename in c_files) {
            var dirname = Path.get_dirname (filename);

            if (c_dirs.contains (dirname)) {
                new_c_dirs.add (dirname);
                continue;
            }

            if (visited_bad.contains (dirname)) {
                new_c_files.add (filename);
                continue;
            }

            try {
                var enumerator = File.new_for_path (dirname).enumerate_children (
                                                                "standard::*",
                                                                FileQueryInfoFlags.NONE,
                                                                null);
                FileInfo info = null;
                var matching = false;
                while (!matching && (info = enumerator.next_file()) != null) {
                    if (info.get_file_type() != FileType.REGULAR ||  //TODO: Follow symlinks.
                                            c_files.contains (Path.build_path (Path.DIR_SEPARATOR_S,
                                                                               dirname,
                                                                               info.get_name())))
                        continue;

                    if (filenames != null) {
                        foreach (var name in filenames)
                            if (Path.get_basename (info.get_name()) == name) {
                                matching = true;
                                break;
                            }
                        if (matching)
                            break;
                    }

                    if (extensions != null)
                        foreach (var ext in extensions) {
                            if (info.get_name().has_suffix (ext)) {
                                matching = true;
                                break;
                            }
                        }
                    else
                        matching = true;
                }
                if (matching) {
                    visited_bad.add (dirname);
                    new_c_files.add (filename);
                } else {
                    c_dirs.add (dirname);
                    new_c_dirs.add (dirname);
                }
            } catch (GLib.Error e) {
                warning_msg (_("Could not list or iterate through directory content of '%s': %s\n"),
                             dirname, e.message);
            }
        }
        c_files = new_c_files;

        foreach (var dirname in c_dirs) {
            if (new_c_dirs.contains (dirname))
                continue;
            try {
                var enumerator = File.new_for_path (dirname).enumerate_children (
                                                                "standard::*",
                                                                FileQueryInfoFlags.NONE,
                                                                null);
                FileInfo info = null;
                var matching = false;
                while (!matching && (info = enumerator.next_file()) != null) {
                    if (info.get_file_type() != FileType.REGULAR)  //TODO: Other FileTypes?
                        continue;

                    if (filenames != null) {
                        foreach (var name in filenames)
                            if (Path.get_basename (info.get_name()) == name) {
                                matching = true;
                                break;
                            }
                        if (matching)
                            break;
                    }

                    if (extensions != null)
                        foreach (var ext in extensions) {
                            if (info.get_name().has_suffix (ext)) {
                                matching = true;
                                break;
                            }
                        }
                    else
                        matching = true;
                }
                if (matching)
                    new_c_dirs.add (dirname);
            } catch (GLib.Error e) {
                warning_msg (_("Could not list or iterate through directory content of '%s': %s\n"),
                             dirname, e.message);
            }
        }
        c_dirs = new_c_dirs;
    }

    public void balance_pfile_dirs() {
        var s_dirs_tmp = new TreeSet<string>();
        var s_files_tmp = files;
        var b_dirs_tmp = new TreeSet<string>();
        var b_files_tmp = b_files;
        var d_dirs_tmp = new TreeSet<string>();
        var d_files_tmp = d_files;
        balance_dir_file_sets (ref s_dirs_tmp, ref s_files_tmp,
                               new string[]{".vala", ".vapi"});
        balance_dir_file_sets (ref b_dirs_tmp, ref b_files_tmp,
                               new string[]{".cmake"}, new string[]{"CMakeLists.txt"});
        balance_dir_file_sets (ref d_dirs_tmp, ref d_files_tmp);

        source_dirs = s_dirs_tmp;
        source_files = s_files_tmp;
        buildsystem_dirs = b_dirs_tmp;
        buildsystem_files = b_files_tmp;
        data_dirs = d_dirs_tmp;
        data_files = d_files_tmp;
    }

    /**
     * Add package to project. Remember to add it later to Guanako project and
     * emit packages_changed signal.
     *
     * @param pkg Package to add.
     */
    public void add_package (PackageInfo pkg) {
        var info = pkg.to_string();
        if (pkg.choice != null)
            info += " (%s)".printf (_("choice"));
        debug_msg_level (2, _("Add package: %s\n"), info);
        packages[pkg.name] = pkg;
    }

    /**
     * Add package to project by package name and update Guanako project.
     *
     * @param pkg Package to add.
     * @return Not available packages.
     */
    public string[] add_package_by_name (string pkg) {
        debug_msg_level (2, _("Add package: %s\n"), pkg);
        var pkginfo = new PackageInfo();
        pkginfo.name = pkg;
        if (!(pkginfo in packages[pkg])) {
            packages[pkg] = pkginfo;
            packages_changed();
        }
        return guanako_project.add_packages (new string[] {pkg}, true);
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
        if (!packages.remove (pkg.name, pkg)) {
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
        if (!(pkg in packages.get_keys())) {
            debug_msg (_("Package '%s' not in list, skip it.\n"), pkg);
            return false;
        }

        foreach (var pkginfo in packages[pkg])
            if (pkginfo.choice != null && !pkginfo.choice.remove_package (pkginfo))
                package_choices.remove (pkginfo.choice);
        packages.remove_all (pkg);

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
    public inline Gee.ArrayList<Guanako.Reporter.Error?> get_errorlist() {
        return guanako_project.get_errorlist();
    }

    /**
     * Add source file and register with Guanako.
     *
     * @param filename Path to file.
     */
    public void add_source_file (string? filename) {
        if (filename == null || !(filename.has_suffix (".vala") || filename.has_suffix (".vapi")))
            return;
        var filename_abs = get_absolute_path (filename);

        var f = File.new_for_path (filename_abs);
        if (!f.query_exists()) {
            warning_msg (_("Source file does not exist: %s\n"), filename_abs);
            return;
        }

        msg (_("Found source file: %s\n"), filename_abs);

        if (b_files.contains (filename_abs)) {
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
     * Add file to build system list.
     *
     * @param filename Path to file.
     */
    public void add_buildsystem_file (string? filename) {
        if (builder == null || filename == null || !builder.check_buildsystem_file (filename))
            return;
        var filename_abs = get_absolute_path (filename);

        var f = File.new_for_path (filename_abs);
        if (!f.query_exists()) {
            warning_msg (_("Build system file does not exist: %s\n"), filename_abs);
            return;
        }

        msg (_("Found build system file: %s\n"), filename_abs);
        if (files.contains (filename_abs)) {
            warning_msg (_("File already a source file. Skip it.\n"), filename_abs);
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
     */
    public void add_data_file (string? filename) {
        if (filename == null)
            return;
        var filename_abs = get_absolute_path (filename);

        var f = File.new_for_path (filename_abs);
        if (!f.query_exists()) {
            warning_msg (_("Data file does not exist: %s\n"), filename_abs);
            return;
        }

        msg (_("Found data file: %s\n"), filename_abs);
        if (files.contains (filename_abs)) {
            warning_msg (_("File already a source file. Skip it.\n"), filename_abs);
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
            warning_msg (_("Could not close ViewMap for: %s\n"), filename);
    }

    /**
     * Callback to perform action with valid file.
     *
     * @param filename Absolute path to existing file.
     */
    public delegate void FileCallback (string filename);
    /**
     * Iterate over directories and files and fill list.
     *
     * @param dirlist List of directories.
     * @param filelist List of files.
     * @param action Method to perform on each found file in directory or
     *               file list.
     */
    public void generate_file_list (string[] dirlist,
                                    string[] filelist,
                                    FileCallback? action = null) {
        File directory;
        FileEnumerator enumerator;
        FileInfo file_info;

        foreach (var dir in dirlist) {
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
                errmsg (_("Could not open file in '%s': %s\n"), dir, e.message);
            }
        }

        foreach (var filename in filelist)
            action (filename);
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
        if (comp_version (project_file_version, VLP_VERSION_MIN) < 0) {
            var errstr = _("Project file too old: %s < %s").printf (project_file_version,
                                                                    VLP_VERSION_MIN);
            if (!Args.forceold) {
                throw new LoadingError.FILE_IS_OLD (errstr);
                delete doc;
            } else
                warning_msg (_("Ignore project file loading error: %s\n"), errstr);
        }

        for (Xml.Node* i = root_node->children; i != null; i = i->next) {
            if (i->type != ElementType.ELEMENT_NODE)
                continue;
            switch (i->name) {
                case "name":
                    project_name = i->get_content();
                    break;
                case "buildsystem":
                    add_builder (i->get_content());
                    break;
                case "version":
                    for (Xml.Node* p = i->children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "major":
                                version_major = int.parse (p->get_content());
                                break;
                            case "minor":
                                version_minor = int.parse (p->get_content());
                                break;
                            case "patch":
                                version_patch = int.parse (p->get_content());
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"),
                                             p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "packages":
                    for (Xml.Node* p = i->children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "choice":
                                var choice = new PkgChoice();
                                if (p->has_prop ("all") != null)
                                    switch (p->get_prop ("all")) {
                                        case "yes":
                                            choice.all = true;
                                            break;
                                        case "no":
                                            choice.all = false;
                                            break;
                                        default:
                                            warning_msg (_("Unknown property for '%s' line %hu: %s\n"
                                                                + "Will choose '%s'\n"),
                                                         "rel", p->line, p->get_prop ("all"), "no");
                                            choice.all = false;
                                            break;
                                    }
                                for (Xml.Node* pp = p->children; pp != null; pp = pp->next) {
                                    if (pp->type != ElementType.ELEMENT_NODE)
                                        continue;
                                    switch (pp->name) {
                                        case "description":
                                            choice.description = pp->get_content();
                                            break;
                                        case "package":
                                            var pkg = get_package_info (pp);
                                            if (pkg != null)
                                                choice.add_package (pkg);
                                            break;
                                        default:
                                            warning_msg (_("Unknown configuration file value line %hu: %s\n"), pp->line, pp->name);
                                            break;
                                    }
                                }
                                if (choice.packages.size > 0)
                                    package_choices.add (choice);
                                else
                                    warning_msg (_("No packages to choose between: line %hu\n"), p->line);
                                break;
                            case "package":
                                var pkg = get_package_info (p);
                                if (pkg != null)
                                    add_package (pkg);
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "source-directories":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "directory":
                                source_dirs.add (get_absolute_path (p->get_content()));
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "source-files":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "file":
                                source_files.add (get_absolute_path (p->get_content()));
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "buildsystem-directories":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "directory":
                                buildsystem_dirs.add (get_absolute_path (p->get_content()));
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "buildsystem-files":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "file":
                                buildsystem_files.add (get_absolute_path (p->get_content()));
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "data-directories":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "directory":
                                data_dirs.add (get_absolute_path (p->get_content()));
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "data-files":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "file":
                                data_files.add (get_absolute_path (p->get_content()));
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "opened-files":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "file":
                                files_opened.add (get_absolute_path (p->get_content()));
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                default:
                    warning_msg (_("Unknown configuration file value line %hu: %s\n"), i->line, i->name);
                    break;
            }
        }

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

        delete doc;
    }

    /**
     * Save project to {@link project_file}.
     *
     * @param balance If `true` balance file and directory lists.
     */
    public void save (bool balance = true) {
        debug_msg (_("Save project file.\n"));

        if (balance)
            balance_pfile_dirs();

        var writer = new TextWriter.filename (project_file);
        writer.set_indent (true);
        writer.set_indent_string ("\t");

        writer.start_element ("project");
        writer.write_attribute ("version", project_file_version);
        writer.write_element ("name", project_name);
        if (builder != null)
            writer.write_element ("buildsystem", builder.get_name_id());

        writer.start_element ("version");
        writer.write_element ("major", version_major.to_string());
        writer.write_element ("minor", version_minor.to_string());
        writer.write_element ("patch", version_patch.to_string());
        writer.end_element();

        if (packages.size > 0 || package_choices.size > 0) {
            writer.start_element ("packages");
            foreach (var choice in package_choices) {
                writer.start_element ("choice");
                writer.write_attribute ("all", (choice.all) ? "yes" : "no");
                if (choice.description != null)
                    writer.write_element ("description", choice.description);
                foreach (var pkg in choice.packages) {
                    writer.write_element ("package", pkg.name);
                    if (pkg.version != null)
                        writer.write_attribute ("version", pkg.version);
                    if (pkg.rel != null)
                        writer.write_attribute ("rel", pkg.rel.to_string());
                }
                writer.end_element();
            }
            foreach (var pkg in packages.get_values()) {
                if (pkg.choice != null)
                    continue;
                writer.start_element ("package");
                if (pkg.version != null)
                    writer.write_attribute ("version", pkg.version);
                if (pkg.rel != null)
                    writer.write_attribute ("rel", pkg.rel.to_string());
                writer.write_string (pkg.name);
                writer.end_element();
            }
            writer.end_element();
        }

        if (source_dirs.size > 0) {
            writer.start_element ("source-directories");
            foreach (var directory in source_dirs)
                writer.write_element ("directory", get_relative_path (directory));
            writer.end_element();
        }

        if (source_files.size > 0) {
            writer.start_element ("source-files");
            foreach (var filename in source_files)
                writer.write_element ("file", get_relative_path (filename));
            writer.end_element();
        }

        if (buildsystem_dirs.size > 0) {
            writer.start_element ("buildsystem-directories");
            foreach (var directory in buildsystem_dirs)
                writer.write_element ("directory", get_relative_path (directory));
            writer.end_element();
        }

        if (buildsystem_files.size > 0) {
            writer.start_element ("buildsystem-files");
            foreach (var filename in buildsystem_files)
                writer.write_element ("file", get_relative_path (filename));
            writer.end_element();
        }

        if (data_dirs.size > 0) {
            writer.start_element ("data-directories");
            foreach (var directory in data_dirs)
                writer.write_element ("directory", get_relative_path (directory));
            writer.end_element();
        }

        if (data_files.size > 0) {
            writer.start_element ("data-files");
            foreach (var filename in data_files)
                writer.write_element ("file", get_relative_path (filename));
            writer.end_element();
        }

        writer.end_element();
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
                        warning_msg (_("Unknown attribute for 's' line %hu: %s\n"),
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
        save();

        if (save_all)
            return buffer_save_all();

        var changed_files = new TreeSet<string>();
        foreach (var map in vieworder) {
            //TOOD: Ask here too if dirty.
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
    public bool add_builder (string? buildsystem) {
        if (buildsystem == null) {
            builder = null;
            return true;
        }
        switch (buildsystem) {
            case "valama":
                builder = new BuilderPlain();
                break;
            case "cmake":
                builder = new BuilderCMake();
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
            var context = new Vala.CodeContext();
            Guanako.Project.context_prep (context, 2, 32);  //TODO: Dynamic version.
            //TODO: Do this like init method in ProjectTemplate (check against all vapis).
            foreach (var pkg in choice.packages)
                if (context.get_vapi_path (pkg.name) != null) {
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
        if ((define in defines) && guanako_project.add_define (define)) {
            defines_update();
            return true;
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
        return guanako_project.remove_define (define);
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
                                   || key.keyval == 65293); // That's Enter
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
        warning_msg (_("File not registered in project to check if buffer is dirty: %s\n"), filename);
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
        if (path.has_prefix (project_path)) {  // only simple string comparison
            var rel = project_path_file.get_relative_path (File.new_for_path (path));
            if (rel == null)
                return "";
            return rel;
        }
        return path;
    }

    /**
     * Load package information from {@link Xml.Node}.
     *
     * @param node Package {@link Xml.Node} to search for infos.
     * @return Return {@link PackageInfo} or null if no package found.
     */
    private PackageInfo? get_package_info (Xml.Node* node) {
        var package = new PackageInfo();
        package.name = node->get_content();
        if (package.name == null)
            return null;
        if (node->has_prop ("version") != null) {
            package.version = node->get_prop ("version");
            if (node->has_prop ("rel") != null)
                switch (node->get_prop ("rel")) {
                    case "since":
                        package.rel = VersionRelation.SINCE;
                        break;
                    case "until":
                        package.rel = VersionRelation.UNTIL;
                        break;
                    case "only":
                        package.rel = VersionRelation.ONLY;
                        break;
                    case "exclude":
                        package.rel = VersionRelation.EXCLUDE;
                        break;
                    default:
                        warning_msg (_("Unknown property for '%s' line %hu: %s\n"
                                            + "Will choose '%s'\n"),
                                     "rel", node->line, node->get_prop ("rel"), "since");
                        package.rel = VersionRelation.SINCE;
                        break;
                }
            else
                package.rel = VersionRelation.SINCE;
        } else if (node->has_prop ("rel") != null)
            warning_msg (_("Package '%s' has relation information but no version: "
                                + "line: %hu: %s\n"),
                         package.name, node->line, node->get_prop ("rel"));
        return package;
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


/**
 * Throw on project file loading errors.
 */
public errordomain LoadingError {
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
    FILE_IS_GARBAGE,
    /**
     * Could not load Guanako completion.
     */
    //TODO: Disable completion instead.
    COMPLETION_NOT_AVAILABLE
}

// vim: set ai ts=4 sts=4 et sw=4
