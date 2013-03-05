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
using Xml;

/**
 * Load Valama project from .vlp (xml) file.
 *
 * @param project {@link ValamaProject} to initilize;
 * @throws LoadingError Throw if file to load contains errors. E.g. it
 *                      does not exist or does not contain enough
 *                      information.
 */
private void load_project_file (ValamaProject project) throws LoadingError {
    Doc* doc = Parser.parse_file (project.project_file);

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
        project.project_file_version = root_node->get_prop ("version");
    else
        project.project_file_version = "0";
    if (comp_proj_version (project.project_file_version, VLP_VERSION_MIN) < 0) {
        var errstr = _("Project file too old: %s < %s").printf (project.project_file_version,
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
                project.project_name = i->get_content();
                break;
            case "buildsystem":
                project.buildsystem = i->get_content();
                break;
            case "version":
                for (Xml.Node* p = i->children; p != null; p = p->next) {
                    if (p->type != ElementType.ELEMENT_NODE)
                        continue;
                    switch (p->name) {
                        case "major":
                            project.version_major = int.parse (p->get_content());
                            break;
                        case "minor":
                            project.version_minor = int.parse (p->get_content());
                            break;
                        case "patch":
                            project.version_patch = int.parse (p->get_content());
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
                                project.add_package_choice (choice);
                            else
                                warning_msg (_("No packages to choose between: line %hu\n"), p->line);
                            break;
                        case "package":
                            var pkg = get_package_info (p);
                            if (pkg != null)
                                project.add_package (pkg);
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
                            project.source_dirs.add (project.get_absolute_path (p->get_content()));
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
                            project.source_files.add (project.get_absolute_path (p->get_content()));
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
                            project.buildsystem_dirs.add (project.get_absolute_path (p->get_content()));
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
                            project.buildsystem_files.add (project.get_absolute_path (p->get_content()));
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

    foreach (var choice in project.package_choices) {
        var pkg = get_choice (choice);
        if (pkg != null)
            project.add_package (pkg);
        else {
            warning_msg (_("Could not select a package from choice.\n"));
            project.add_package (choice.packages[0]);
        }
    }
    delete doc;
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


/**
 * Select first available package of {@link PkgChoice}. Does not check for
 * conflicts.
 *
 * @param choide {@link PkgChoice} to search for available packages.
 * @return Return available package name or null.
 */
//TODO: Check version.
public PackageInfo? get_choice (PkgChoice choice) {
    Vala.CodeContext context;
    // if (guanako_project != null)
        // context = guanako_project.context;
    // else {
        context = new Vala.CodeContext();
        context.target_glib_major = 2;  //TODO: Use Guanako.context_prep.
        context.target_glib_minor = 32;
        for (int i = 16; i <= context.target_glib_minor; i += 2)
            context.add_define (@"GLIB_$(context.target_glib_major)_$i");
        context.profile = Vala.Profile.GOBJECT;
    // }
    //TODO: Do this like init method in ProjectTemplate (check against all vapis).
    foreach (var pkg in choice.packages)
        if (context.get_vapi_path (pkg.name) != null) {
            debug_msg (_("Choose '%s' package.\n"), pkg.name);
            return pkg;
        } else
            debug_msg (_("Skip '%s' choice.\n"), pkg.name);
    return null;
}


/**
 * Save project to project file.
 *
 * @param project {@link ValamaProject} to save.
 */
public void save_project_file (ValamaProject project) {
    debug_msg (_("Save project file.\n"));

    var writer = new TextWriter.filename (project.project_file);
    writer.set_indent (true);
    writer.set_indent_string ("\t");

    writer.start_element ("project");
    writer.write_attribute ("version", project.project_file_version);
    writer.write_element ("name", project.project_name);
    writer.write_element ("buildsystem", project.buildsystem);

    writer.start_element ("version");
    writer.write_element ("major", project.version_major.to_string());
    writer.write_element ("minor", project.version_minor.to_string());
    writer.write_element ("patch", project.version_patch.to_string());
    writer.end_element();

    writer.start_element ("packages");
    foreach (var choice in project.package_choices) {
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
    foreach (var pkg in project.packages) {
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

    writer.start_element ("source-directories");
    foreach (string directory in project.source_dirs)
        writer.write_element ("directory", project.get_relative_path (directory));
    writer.end_element();

    writer.start_element ("source-files");
    foreach (string directory in project.source_files)
        writer.write_element ("file", project.get_relative_path (directory));
    writer.end_element();

    writer.start_element ("buildsystem-directories");
    foreach (string directory in project.buildsystem_dirs)
        writer.write_element ("directory", project.get_relative_path (directory));
    writer.end_element();

    writer.start_element ("buildsystem-files");
    foreach (string directory in project.buildsystem_files)
        writer.write_element ("file", project.get_relative_path (directory));
    writer.end_element();

    writer.end_element();
}

// vim: set ai ts=4 sts=4 et sw=4
