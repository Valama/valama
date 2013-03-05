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
 * Vala package alternatives.
 */
public class PkgChoice {
    /**
     * Indicate if all packages should go to buildsystem package list.
     */
    public bool all = false;
    /**
     * Ordered list of packages. Packages in the front have higher
     * priority.
     */
    public ArrayList<PackageInfo?> packages { get; private set; }
    /**
     * Optional description.
     */
    public string? description = null;

    public PkgChoice() {
        packages = new ArrayList<PackageInfo?>();
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
    public PkgChoice? choice = null;
    /**
     * Version relation.
     */
    public VersionRelation? rel = null;
    /**
     * Package name.
     */
    public string name;
    /**
     * Version (meaning differs with {@link rel}).
     */
    public string? version = null;

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
                    bug_msg (_("Unexpected enum value: %s: %d\n"),
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

        int verrel = strcmp (pkg1.version, pkg2.version);
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


public abstract class RawValamaProject : Object {
    private string _project_path;
    /**
     * Absolute path to project root.
     */
    public string project_path {
        get {
            return _project_path;
        }
        protected set {
            _project_path = value;
            project_path_file = File.new_for_path (value);
        }
    }
    /**
     * Project path file object.
     */
    public File project_path_file { get; protected set; }
    /**
     * Absolute path to project file.
     */
    public string project_file { get; protected set; }
    private string _project_file_version = null;
    /**
     * Version of .vlp file
     *
     * Setter method is readonly.
     */
    public string project_file_version {
        get {
            return _project_file_version;
        }
        set {
            /* Allow writing for only one time (loading of project file. */
            assert (_project_file_version == null);
            _project_file_version = value;
        }
    }
    /**
     * List of package choices.
     */
    public ArrayList<PkgChoice?> package_choices { get; protected set; }
    /**
     * Project source directories (absolute paths).
     */
    public TreeSet<string> source_dirs { get; protected set; }
    /**
     * Project extra source files (absolute paths).
     */
    public TreeSet<string> source_files { get; protected set; }
    /**
     * Project buildsystem directories (absolute paths).
     */
    public TreeSet<string> buildsystem_dirs { get; protected set; }
    /**
     * Project extra buildsystem files (absolute paths).
     */
    public TreeSet<string> buildsystem_files { get; protected set; }
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
     * List of source files.
     */
    public TreeSet<string> files { get; protected set; }
    /**
     * List of buildsystem files.
     */
    public TreeSet<string> b_files { get; protected set; }
    /**
     * The project's buildsystem (valama/cmake/...).
     */
    public string buildsystem = "cmake";
    /**
     * Required packages with version information.
     *
     * Use {@link add_package} or {@link add_package_by_name} to add a new
     * package.
     */
    public TreeSet<PackageInfo?> packages { get; protected set; }
    /**
     * List of packages without version information.
     *
     * Use {@link add_package} or {@link add_package_by_name} to add a new
     * package.
     */
    public TreeSet<string> package_list { get; protected set; }

    /**
     * Add package to project.
     *
     * @param pkg Package.
     */
    public void add_package (PackageInfo pkg) {
        packages.add (pkg);
        package_list.add (pkg.name);
    }

    /**
     * Add package to project by package name.
     *
     * @param pkg Package.
     */
    public void add_package_by_name (string pkg) {
        var pkginfo = new PackageInfo();
        pkginfo.name = pkg;
        packages.add (pkginfo);
        package_list.add (pkg);
    }

    /**
     * Add package choice to project.
     *
     * @param pkg Package.
     */
    public void add_package_choice (PkgChoice choice) {
        package_choices.add (choice);
    }

    /**
     * Add sourcefile to project.
     *
     * @param filename Absolute path to file.
     */
    public abstract void add_source_file (string filename);

    /**
     * Remove sourcefile from project and unlink from Guanako. Don't remove
     * file from disk. Keep track to not include it with source directories
     * next time.
     *
     * @param filename Absolute path to file to unregister.
     * @return Return true on success else false (e.g. if file was not found).
     */
    public abstract bool remove_source_file (string filename);

    /**
     * Add file to buildsystem list.
     *
     * @param filename Path to file.
     */
    protected void add_buildsystem_file (string filename) {
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

        foreach (string dir in dirlist) {
            try {
                directory = File.new_for_path (dir);
                enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

                while ((file_info = enumerator.next_file()) != null)
                    action (Path.build_path (Path.DIR_SEPARATOR_S,
                                             dir,
                                             file_info.get_name()));
            } catch (GLib.Error e) {
                errmsg (_("Could not open file in '%s': %s\n"), dir, e.message);
            }
        }

        foreach (string filename in filelist) {
                var file = File.new_for_path (filename);
                if (file.query_exists())
                    action (filename);
                else
                    warning_msg (_("File not found: %s\n"), filename);
        }
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
