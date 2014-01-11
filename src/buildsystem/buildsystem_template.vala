/*
 * src/buildsystem/base.vala
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

using GLib;
using Gee;
using Xml;

public class BuildSystemTemplate : Object {
    public Gdk.Pixbuf? icon = null;
    public ArrayList<TemplateAuthor?> authors = new ArrayList<TemplateAuthor?>();
    public string version = "0";
    public string name;
    public string path;
    public string description;
    public string? long_description = null;

    public BuildSystem? system = null;
    
    

    public static bool load_buildsystems (bool reload = false) {
        if (buildsystems == null)
            buildsystems = new Gee.TreeMap<string, BuildSystemTemplate>();
        else if (reload)
            buildsystems.clear();
        else
            return false;

        string[] dirpaths;
        if (Args.buildsystemsdirs == null)
            dirpaths = new string[] {
                                      Path.build_path (Path.DIR_SEPARATOR_S,
                                                       Environment.get_user_data_dir(),
                                                       "valama",
                                                       "buildsystems"),
                                      Path.build_path (Path.DIR_SEPARATOR_S,
                                                       Config.PACKAGE_DATA_DIR,
                                                       "buildsystems")
                                    };
        else
            dirpaths = Args.buildsystemsdirs;

        foreach (var dirpath in dirpaths) {
            if (!FileUtils.test (dirpath, FileTest.IS_DIR))
                continue;
            debug_msg ("Checking template directory: %s\n", dirpath);
            try {
                var enumerator = File.new_for_path (dirpath).enumerate_children (FileAttribute.STANDARD_NAME, 0);

                FileInfo file_info;
                while ((file_info = enumerator.next_file()) != null) {
                    var infof = File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S,
                                                                    dirpath,
                                                                    file_info.get_name(),
                                                                    file_info.get_name() + ".info"));
                    if (!infof.query_exists())
                        continue;
                    var filename = infof.get_path();

                    var new_buildsystem = new BuildSystemTemplate();
                    new_buildsystem.name = file_info.get_name();
                    //TODO: Check if patch exists.
                    new_buildsystem.path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                            dirpath,
                                                            new_buildsystem.name,
                                                            "buildsystem");
                    foreach (var filetype in get_insensitive_cases({"png","jpg","jpeg","svg"})) {
                        var icon_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                         dirpath,
                                                         new_buildsystem.name,
                                                         new_buildsystem.name + "." + filetype);
                        if (FileUtils.test (icon_path, FileTest.EXISTS)) {
                            try {
                                var pbuf = new Gdk.Pixbuf.from_file (icon_path);
                                new_buildsystem.icon = pbuf.scale_simple (33, 33, Gdk.InterpType.BILINEAR);
                                break;
                            } catch (GLib.Error e) {
                                warning_msg (_("Could not load build system image: %s\n"), e.message);
                            }
                        }
                    }

                    Xml.Doc* doc = Xml.Parser.parse_file (filename);
                    Xml.Node* root_node;

                    try {
                        if (doc == null) {
                            delete doc;
                            throw new LoadingError.FILE_IS_GARBAGE (_("Cannot parse file."));
                        }

                        root_node = doc->get_root_element();
                        if (root_node == null) {
                            delete doc;
                            throw new LoadingError.FILE_IS_EMPTY (_("File does not contain enough information"));
                        }

                        if (root_node->has_prop ("version") != null)
                            new_buildsystem.version = root_node->get_prop ("version");
                        if (comp_version (new_buildsystem.version, BUILDSYSTEM_VERSION_MIN) < 0) {
                            var errstr = _("Build system file '%s' too old: %s < %s").printf (new_buildsystem.path,
                                                                                              new_buildsystem.version,
                                                                                              BUILDSYSTEM_VERSION_MIN);
                            if (!Args.forceold) {
                                delete doc;
                                throw new LoadingError.FILE_IS_OLD (errstr);
                            } else
                                warning_msg (_("Ignore build system file loading error: %s\n"), errstr);
                        }
                    } catch (LoadingError e) {
                        warning_msg (_("Could not load build system '%s': %s\n"), filename, e.message);
                        continue;
                    }

                    for (Xml.Node* i = root_node->children; i != null; i = i->next) {
                        if (i->type != ElementType.ELEMENT_NODE)
                            continue;
                        switch (i->name) {
                            case "author":
                                var author = new TemplateAuthor();
                                for (Xml.Node* p = i->children; p != null; p = p->next) {
                                    if (p->type != ElementType.ELEMENT_NODE)
                                        continue;
                                    switch (p->name) {
                                        case "name":
                                            author.name = p->get_content();
                                            break;
                                        case "mail":
                                            author.mail = p->get_content();
                                            break;
                                        case "date":
                                            author.date = p->get_content();
                                            break;
                                        case "comment":
                                            author.comment = get_lang_content (p);
                                            break;
                                        default:
                                            warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                            break;
                                    }
                                }
                                new_buildsystem.authors.add (author);
                                break;
                            case "name":
                                var tmpname = get_lang_content (i);
                                if (tmpname == null) {
                                    warning_msg (_("Build system has no name: line %hu"), i->line);
                                    new_buildsystem.name = "";
                                } else
                                    new_buildsystem.name = tmpname.down();
                                break;
                            case "description":
                                new_buildsystem.description = get_lang_content (i);
                                if (new_buildsystem.description == null) {
                                    debug_msg (_("Build system has no description: line %hu"), i->line);
                                    new_buildsystem.description = "";
                                }
                                break;
                            case "long-description":
                                new_buildsystem.long_description = get_lang_content (i);
                                break;
                            default:
                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), i->line, i->name);
                                break;
                        }
                    }
                    delete doc;
                    buildsystems[new_buildsystem.name] = new_buildsystem;
                }
            } catch (GLib.Error e) {
                errmsg (_("Could not process files in template directory: %s\n"), e.message);
            }
        }

        return true;
    }

}

/**
 * Current compatible version of build system file.
 */
public const string BUILDSYSTEM_VERSION_MIN = "0.1";

// vim: set ai ts=4 sts=4 et sw=4
