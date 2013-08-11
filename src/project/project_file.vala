/*
 * src/project/project_file.vala
 * Copyright (C) 2013, Valama development team
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
using Gee;
using Xml;

/**
 * Current compatible version of project file.
 */
const string VLP_VERSION_MIN = "0.1";

public class ProjectFile : Object {
    public ProjectFile (string project_file) throws LoadingError {
        this.project_file_path = project_file;

        var proj_file = File.new_for_path (project_file);
        project_path = proj_file.get_parent().get_path(); //TODO: Check valid path?

        load_project_file();
    }

    public string project_file_path  { get; private set; }

    //TODO: eliminate one of these two...
    public File project_path_file { get; private set; }
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

    public string project_name { get; set; default = _("valama_project"); }
    public string project_file_version { get; private set; default = "0"; }

    public int version_major { get; set; default = 0; }
    public int version_minor { get; set; default = 0; }
    public int version_patch { get; set; default = 0; }

    public ArrayList<PkgChoice?> package_choices { get; private set; default = new ArrayList<PkgChoice?>(); }

    protected TreeSet<string> _source_dirs = new TreeSet<string>();
    public TreeSet<string> source_dirs { get { return _source_dirs; } protected set { _source_dirs = value; } }

    protected TreeSet<string> _source_files = new TreeSet<string>();
    public TreeSet<string> source_files { get { return _source_files; } protected set { _source_files = value; } }

    protected TreeSet<string> _ui_dirs = new TreeSet<string>();
    public TreeSet<string> ui_dirs { get { return _ui_dirs; } protected set { _ui_dirs = value; } }

    protected TreeSet<string> _ui_files = new TreeSet<string>();
    public TreeSet<string> ui_files { get { return _ui_files; } protected set { _ui_files = value; } }

    protected TreeSet<string> _buildsystem_dirs = new TreeSet<string>();
    public TreeSet<string> buildsystem_dirs { get { return _buildsystem_dirs; } protected set { _buildsystem_dirs = value; } }

    protected TreeSet<string> _buildsystem_files = new TreeSet<string>();
    public TreeSet<string> buildsystem_files { get { return _buildsystem_files; } protected set { _buildsystem_files = value; } }

    protected TreeSet<string> _data_dirs = new TreeSet<string>();
    public TreeSet<string> data_dirs { get { return _data_dirs; } protected set { _data_dirs = value; } }

    protected TreeSet<string> _data_files = new TreeSet<string>();
    public TreeSet<string> data_files { get { return _data_files; } protected set { _data_files = value; } }

    /**
     * List of source files.
     */
    public TreeSet<string> files { get; private set; default = new TreeSet<string>(); }
    /**
     * List of user interface files.
     */
    public TreeSet<string> u_files { get; private set; default = new TreeSet<string>(); }
    /**
     * List of build system files.
     */
    public TreeSet<string> b_files { get; private set; default = new TreeSet<string>(); }
    /**
     * List of extra files.
     */
    public TreeSet<string> d_files { get; private set; default = new TreeSet<string>(); }


    public TreeMap<string, PackageInfo?> packages { get; private set;
        default = new TreeMap<string, PackageInfo?> (null, (EqualDataFunc<PackageInfo?>?) PackageInfo.compare_func);
    }

    /**
     * List of opened files.
     */
    //TODO: Support only for templates and not normal projects.
    public ArrayList<string> files_opened { get; protected set; default = new ArrayList<string>(); }

    public string buildsystem { get; protected set; default = ""; }

     /**
     * Load Valama project from .vlp (xml) file.
     *
     * @throws LoadingError Throw if file to load contains errors. E.g. it
     *                      does not exist or does not contain enough
     *                      information.
     */
    private void load_project_file() throws LoadingError {
        Xml.Doc* doc = Xml.Parser.parse_file (project_file_path);

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
                    buildsystem = i->get_content();
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
                                    packages[pkg.name] = pkg;
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
                case "ui-directories":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "directory":
                                ui_dirs.add (get_absolute_path (p->get_content()));
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                break;
                        }
                    }
                    break;
                case "ui-files":
                    for (Xml.Node* p = i-> children; p != null; p = p->next) {
                        if (p->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (p->name) {
                            case "file":
                                ui_files.add (get_absolute_path (p->get_content()));
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

        delete doc;
    }


    /**
     * Save project to {@link project_file_path}.
     *
     * @param balance If `true` balance file and directory lists.
     */
    public void save_project_file (bool balance = true) {
        debug_msg (_("Save project file: %s\n"), project_file_path);

        if (balance)
            balance_pfile_dirs();

        var writer = new TextWriter.filename (project_file_path);
        writer.set_indent (true);
        writer.set_indent_string ("\t");

        writer.start_element ("project");
        writer.write_attribute ("version", project_file_version);
        writer.write_element ("name", project_name);
        if (buildsystem != "")
            writer.write_element ("buildsystem", buildsystem);

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
                foreach (var pkg in choice.packages)
                    write_pkg (writer, pkg);
                writer.end_element();
            }
            foreach (var pkg in packages.values) {
                if (pkg.choice != null)
                    continue;
                write_pkg (writer, pkg);
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

        if (ui_dirs.size > 0) {
            writer.start_element ("ui-directories");
            foreach (var directory in ui_dirs)
                writer.write_element ("directory", get_relative_path (directory));
            writer.end_element();
        }

        if (ui_files.size > 0) {
            writer.start_element ("ui-files");
            foreach (var filename in ui_files)
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
    /**
     * Load package information from {@link Xml.Node}.
     *
     * @param node Package {@link Xml.Node} to search for infos.
     * @return Return {@link PackageInfo} or null if no package found.
     */
    private PackageInfo? get_package_info (Xml.Node* node) {
        if (node->has_prop ("name") == null) {
            warning_msg (_("No package name line %hu.\n"), node->line);
            return null;
        }
        var package = new PackageInfo();
        package.name = node->get_prop ("name");

        if (node->has_prop ("version") != null) {
            package.version = node->get_prop ("version");
            if (node->has_prop ("rel") != null) {
                var rel = VersionRelation.name_to_rel (node->get_prop ("rel"));
                if (rel != null)
                    package.rel = rel;
                else {
                    warning_msg (_("Unknown property for '%s' line %hu: %s\n"
                                        + "Will choose '%s'\n"),
                                 "rel", node->line, node->get_prop ("rel"), "since");
                    package.rel = VersionRelation.SINCE;
                }
            } else
                package.rel = VersionRelation.SINCE;
        } else if (node->has_prop ("rel") != null)
            // TRANSLATORS:
            // That means we know "`package' >= ". Something is missing, isn't it?
            warning_msg (_("Package '%s' has relation information but no version: "
                                + "line: %hu: %s\n"),
                         package.name, node->line, node->get_prop ("rel"));

        if (node->has_prop ("vapi") != null) {
            var vapi = node->get_prop ("vapi");
            if (vapi.has_suffix (".vapi"))
                package.custom_vapi = vapi;
            else
                warning_msg (_("Custom vapi '%s' has incorrect file name extension line: %hu\n"),
                             vapi, node->line);
        }
        if (node->has_prop ("nodeps") != null)
            switch (node->get_prop ("nodeps")) {
                case "true":
                    package.nodeps = true;
                    break;
                case "false":
                    package.nodeps = false;
                    break;
                default:
                    warning_msg (_("Unknown property for '%s' line %hu: %s\n"
                                        + "Will choose '%s'\n"),
                                 "nodeps", node->line, node->get_prop ("nodeps"), "false");
                    break;
            }
        if (node->has_prop ("define") != null)
            package.define = node->get_prop ("define");

        for (Xml.Node* p = node->children; p != null; p = p->next) {
            if (p->type != ElementType.ELEMENT_NODE)
                continue;
            switch (p->name) {
                case "extracheck":
                    var pkgcheck = new PkgCheck();
                    if (p->has_prop ("vapi") != null)
                        pkgcheck.custom_vapi = p->get_prop ("vapi");
                    if (p->has_prop ("define") != null)
                        pkgcheck.define = p->get_prop ("define");
                    for (Xml.Node* pp = p->children; pp != null; pp = pp->next) {
                        if (pp->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (pp->name) {
                            case "description":
                                pkgcheck.description = pp->get_content();
                                break;
                            case "package":
                                var pkg = get_package_info (pp);
                                if (pkg != null)
                                    pkgcheck.add_package (pkg);
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"),
                                             pp->line, pp->name);
                                break;
                        }
                    }
                    debug_msg (_("PkgCheck for package '%s' found: %s\n"), package.name, pkgcheck.to_string());
                    if (package.extrachecks == null)
                        package.extrachecks = new ArrayList<PkgCheck>();
                    package.extrachecks.add (pkgcheck);
                    break;
                default:
                    warning_msg (_("Unknown configuration file value line %hu: %s\n"),
                                 p->line, p->name);
                    break;
            }
        }

        return package;
    }

    private void write_pkg (TextWriter writer, PackageInfo pkg) {
        writer.start_element ("package");
        writer.write_attribute ("name", pkg.name);
        if (pkg.version != null)
            writer.write_attribute ("version", pkg.version);
        if (pkg.rel != null)
            writer.write_attribute ("rel", pkg.rel.to_string());
        if (pkg.custom_vapi != null && pkg.save_vapi)
            writer.write_attribute ("vapi", pkg.custom_vapi);
        if (pkg.nodeps != null)
            writer.write_attribute ("nodeps", (pkg.nodeps) ? "true" : "false");
        if (pkg.define != null)
            writer.write_attribute ("define", pkg.define);
        if (pkg.extrachecks != null)
            foreach (var extracheck in pkg.extrachecks) {
                writer.start_element ("extracheck");
                if (extracheck.description != null)
                    writer.write_element ("description", extracheck.description);
                if (extracheck.custom_vapi != null)
                    writer.write_attribute ("vapi", extracheck.custom_vapi);
                if (extracheck.define != null)
                    writer.write_attribute ("define", extracheck.define);
                foreach (var checkpkg in extracheck.packages)
                    write_pkg (writer, checkpkg);
                writer.end_element();
            }
        writer.end_element();
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

    public void balance_pfile_dirs (bool check = true) {
        var s_dirs_tmp = source_dirs;
        var s_files_tmp = files;
        var u_dirs_tmp = ui_dirs;
        var u_files_tmp = ui_files;
        var b_dirs_tmp = buildsystem_dirs;
        var b_files_tmp = b_files;
        var d_dirs_tmp = data_dirs;
        var d_files_tmp = d_files;

        balance_dir_file_sets (ref s_dirs_tmp, ref s_files_tmp,
                               new string[]{".vala", ".vapi"}, null,
                               check);
        balance_dir_file_sets (ref u_dirs_tmp, ref u_files_tmp,
                               new string[]{".ui", ".glade", ".xml"}, null,
                               check);
        balance_dir_file_sets (ref b_dirs_tmp, ref b_files_tmp,
                               new string[]{".cmake"}, new string[]{"CMakeLists.txt"},
                               check);
        balance_dir_file_sets (ref d_dirs_tmp, ref d_files_tmp,
                               null, null,
                               check);

        source_dirs = s_dirs_tmp;
        source_files = s_files_tmp;
        ui_dirs = u_dirs_tmp;
        ui_files = u_files_tmp;
        buildsystem_dirs = b_dirs_tmp;
        buildsystem_files = b_files_tmp;
        data_dirs = d_dirs_tmp;
        data_files = d_files_tmp;
    }

    /**
     * Reduce length of file list: Prefer directories and optionally remove
     * directories without content.
     *
     * @param c_dirs Directories.
     * @param c_files Files.
     * @param extensions Valid file extensions.
     * @param check Check file/directory existence.
     * @param rmdir Remove empty directories.
     */
    private void balance_dir_file_sets (ref TreeSet<string> c_dirs,
                                        ref TreeSet<string> c_files,
                                        string[]? extensions = null,
                                        string[]? filenames = null,
                                        bool check = false,
                                        bool rmdir = false) {
        var visited_bad = new TreeSet<string>();
        var new_c_files = new TreeSet<string>();

        if (check) {
            var removals = new TreeSet<string>();
            foreach (var dir in c_dirs)
                if (!FileUtils.test (dir, FileTest.IS_DIR))
                    removals.add (dir);
            foreach (var dir in removals)
                c_dirs.remove (dir);
        }
        var new_c_dirs = (rmdir) ? new TreeSet<string>() : c_dirs;

        foreach (var filename in c_files) {
            if (check && !FileUtils.test (filename, FileTest.IS_REGULAR))
                continue;

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

        if (rmdir) {
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
    //TODO: Disable completion instead. This is ValamaProject specific so remove it.
    COMPLETION_NOT_AVAILABLE
}

// vim: set ai ts=4 sts=4 et sw=4
