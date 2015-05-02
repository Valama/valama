
public class ProjectTemplate {

  public string name;
  public string author_name;
  public string author_mail;
  public string description;
  public string template_path;
  public string? icon_path;

  public ProjectTemplate(string path) {
    template_path = path + "/template";

    icon_path = path + "/icon.png";
    if (!File.new_for_path(icon_path).query_exists())
      icon_path = null;
    // Load document
    Xml.Doc* doc = Xml.Parser.parse_file (path + "/template.info");
    // if (doc == null)
    //  throw new ProjectError.FILE(_("Project file not found or permissions missing"));

    Xml.Node* root = doc->get_root_element ();
    // if (root == null)
    //  throw new ProjectError.FILE(_("Project file empty"));

    // Check file format version
    string format_version = null;
    for (Xml.Attr* prop = root->properties; prop != null; prop = prop->next)
      if (prop->name == "format_version") {
        format_version = prop->children->content;
      }
    if (format_version == null || format_version != "1") {
      //TODO: handle error properly
      stdout.printf ("incompatible template version\n");
      delete doc;
      return;
    }

    // Iterate first level of project file
    for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
      if (iter->type != Xml.ElementType.ELEMENT_NODE)
        continue;

      if (iter->name == "name") {
        for (Xml.Node* sub_iter = iter->children; sub_iter != null; sub_iter = sub_iter->next) {
          if (sub_iter->type != Xml.ElementType.ELEMENT_NODE)
            continue;
          if (sub_iter->name == "en")
            name = sub_iter->get_content();
        }
      } else if (iter->name == "description") {
        for (Xml.Node* sub_iter = iter->children; sub_iter != null; sub_iter = sub_iter->next) {
          if (sub_iter->type != Xml.ElementType.ELEMENT_NODE)
            continue;
          if (sub_iter->name == "en")
            description = sub_iter->get_content();
        }
      } else if (iter->name == "author") {
        for (Xml.Node* sub_iter = iter->children; sub_iter != null; sub_iter = sub_iter->next) {
          if (sub_iter->type != Xml.ElementType.ELEMENT_NODE)
            continue;
          if (sub_iter->name == "name")
            author_name = sub_iter->get_content();
          else if (sub_iter->name == "mail")
            author_mail = sub_iter->get_content();
        }
      }
    }
    delete doc;
  }

  // Installs the template and returns a Project
  public Project.Project install (string proj_name, string target_dir) {
    DirUtils.create_with_parents (target_dir, 509); // = 775 octal

    var target = File.new_for_path (target_dir);
    copy_recursive (File.new_for_path (template_path), target);

    // Move project file to appropriate name
    var proj_file = File.new_for_path (target.get_path() + "/template.vlp");
    var proj_file_path = target.get_path() + "/" + proj_name + ".vlp";
    proj_file.move (File.new_for_path (proj_file_path), FileCopyFlags.NONE);

    var project = new Project.Project();
    project.load (proj_file_path);
    project.id = Random.next_int ().to_string(); // Set unique ID

    return project;
  }

  // Recursive copying
  // From http://stackoverflow.com/questions/16453739/how-do-i-recursively-copy-a-directory-using-vala
  private bool copy_recursive (GLib.File src, GLib.File dest, GLib.FileCopyFlags flags = GLib.FileCopyFlags.NONE, GLib.Cancellable? cancellable = null) throws GLib.Error {
    GLib.FileType src_type = src.query_file_type (GLib.FileQueryInfoFlags.NONE, cancellable);
    if (src_type == GLib.FileType.DIRECTORY ) {
      if (!dest.query_exists())
        dest.make_directory (cancellable);
      src.copy_attributes (dest, flags, cancellable);

      string src_path = src.get_path ();
      string dest_path = dest.get_path ();
      GLib.FileEnumerator enumerator = src.enumerate_children (GLib.FileAttribute.STANDARD_NAME, GLib.FileQueryInfoFlags.NONE, cancellable);
      for ( GLib.FileInfo? info = enumerator.next_file (cancellable) ; info != null ; info = enumerator.next_file (cancellable) ) {
        copy_recursive (
          GLib.File.new_for_path (GLib.Path.build_filename (src_path, info.get_name ())),
          GLib.File.new_for_path (GLib.Path.build_filename (dest_path, info.get_name ())),
          flags,
          cancellable);
      }
    } else if ( src_type == GLib.FileType.REGULAR ) {
      src.copy (dest, flags, cancellable);
    }

    return true;
  }
}

public class ProjectTemplateProvider {
  public Gee.LinkedList<ProjectTemplate?> templates = new Gee.LinkedList<ProjectTemplate?>();
  public ProjectTemplateProvider() {
    var templates_path = Config.DATA_DIR + "/templates";
    var templates_dir = File.new_for_path (templates_path);

    FileEnumerator enumerator = templates_dir.enumerate_children (GLib.FileAttribute.STANDARD_NAME, GLib.FileQueryInfoFlags.NONE);
    for (GLib.FileInfo? info = enumerator.next_file(); info != null; info = enumerator.next_file() ) {
      templates.add (new ProjectTemplate (templates_path + "/" + info.get_name()));
    }
  }
  
}
