/**
 * src/project_templates.vala
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

using GLib;
using Xml;

public class ProjectTemplate {
    public string name;
    public string path;
    public string description;
    public Gdk.Pixbuf icon = null;
}

/*
 * Template info parser
 */
public ProjectTemplate[] load_templates(string language){
    FileInfo file_info;
    ProjectTemplate[] ret = new ProjectTemplate[0];

    var directory = File.new_for_path ("/usr/share/valama/templates");
    try {
        var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

        while ((file_info = enumerator.next_file()) != null) {
            //string file = project_path + source_dir + "/" + file_info.get_name();
            string filename = file_info.get_name();
            if (!filename.has_suffix(".info"))
                continue;

            var new_template = new ProjectTemplate();
            new_template.name = filename.substring(0, filename.length - 5);
            new_template.path = "/usr/share/valama/templates/" + new_template.name;
            string icon_path = "/usr/share/valama/templates/" + new_template.name + ".png";
            if (FileUtils.test(icon_path, FileTest.EXISTS))
                new_template.icon = new Gdk.Pixbuf.from_file("/usr/share/valama/templates/" + new_template.name + ".png");

            Xml.Doc* doc = Xml.Parser.parse_file ("/usr/share/valama/templates/" + filename);

            if (doc == null) {
                delete doc;
                throw new LoadingError.FILE_IS_GARBAGE ("Cannot parse file.");
            }

            Xml.Node* root_node = doc->get_root_element();
            if (root_node == null) {
                delete doc;
                throw new LoadingError.FILE_IS_EMPTY ("File does not contain enough information");
            }

            for (Xml.Node* i = root_node->children; i != null; i = i->next) {
                if (i->type != ElementType.ELEMENT_NODE)
                    continue;
                if (i->name == "name"){
                    string name_en = "", name_local = "";
                    for (Xml.Node* p = i->children; p != null; p = p->next) {
                        if (p->name == "en")
                            name_en = p->get_content();
                        if (p->name == "language")
                            name_local = p->get_content();
                    }
                    if (name_local == "")
                        name_local = name_en;
                    new_template.name = name_local;
                }
                if (i->name == "description"){
                    string desc_en = "", desc_local = "";
                    for (Xml.Node* p = i->children; p != null; p = p->next) {
                        if (p->name == "en")
                            desc_en = p->get_content();
                        if (p->name == "language")
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
        stderr.printf ("Couln't get template information: %s", e.message);
    }

    return ret;
}

// vim: set ai ts=4 sts=4 et sw=4
