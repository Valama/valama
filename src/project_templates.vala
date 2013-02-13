/*
 * src/project_templates.vala
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

public class ProjectTemplate {
    public string name;
    public string path;
    public string description;
    public Gdk.Pixbuf icon = null;
}

/**
 * Load all available {@link ProjectTemplate} information.
 *
 * @param language Current locale.
 * @return Return list of all found templates.
 */
public ProjectTemplate[] load_templates (string language){
    FileInfo file_info;
    ProjectTemplate[] ret = new ProjectTemplate[0];

    var dirpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                   Config.PACKAGE_DATA_DIR,
                                   "templates");
    var directory = File.new_for_path (dirpath);
    try {
        var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

        while ((file_info = enumerator.next_file()) != null) {
            var infof = File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S,
                                                            dirpath,
                                                            file_info.get_name(),
                                                            file_info.get_name() + ".info"));
            if (!infof.query_exists())
                continue;
            string filename = infof.get_path();

            var new_template = new ProjectTemplate();
            new_template.name = file_info.get_name();
            new_template.path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                 dirpath,
                                                 new_template.name,
                                                 "template");
            string icon_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                dirpath,
                                                new_template.name,
                                                new_template.name + ".png");
            if (FileUtils.test (icon_path, FileTest.EXISTS))
                new_template.icon = new Gdk.Pixbuf.from_file (icon_path);

            Xml.Doc* doc = Xml.Parser.parse_file (filename);

            if (doc == null) {
                delete doc;
                throw new LoadingError.FILE_IS_GARBAGE (_("Cannot parse file."));
            }

            Xml.Node* root_node = doc->get_root_element();
            if (root_node == null) {
                delete doc;
                throw new LoadingError.FILE_IS_EMPTY (_("File does not contain enough information"));
            }

            for (Xml.Node* i = root_node->children; i != null; i = i->next) {
                if (i->type != ElementType.ELEMENT_NODE)
                    continue;
                //TODO: Author/mail handling
                if (i->name == "name") {
                    string name_en = "", name_local = "";
                    for (Xml.Node* p = i->children; p != null; p = p->next) {
                        if (p->name == "en")
                            name_en = p->get_content();
                        else if (p->name == "language")
                            name_local = p->get_content();
                    }
                    if (name_local == "")
                        name_local = name_en;
                    new_template.name = name_local;
                } else if (i->name == "description") {
                    string desc_en = "", desc_local = "";
                    for (Xml.Node* p = i->children; p != null; p = p->next) {
                        if (p->name == "en")
                            desc_en = p->get_content();
                        else if (p->name == "language")
                            desc_local = p->get_content();
                    }
                    if (desc_local == "")
                        desc_local = desc_en;
                    new_template.description = desc_local;
                }
            }
            delete doc;
            ret += new_template;
        }
    } catch (GLib.Error e) {
        errmsg (_("Couln't get template information: %s\n"), e.message);
    }

    return ret;
}

// vim: set ai ts=4 sts=4 et sw=4
