
namespace Project {

  public errordomain ProjectError {
    FILE,
    VERSION,
    CORRUPT_MEMBER
  }

  public class Project {
  
    public string name;
    public string id;

    public Gee.ArrayList<ProjectMember> members = new Gee.ArrayList<ProjectMember>();
    
    public string filename;
    public string basepath;

    public signal void member_added (ProjectMember member);
    public signal void member_removed (ProjectMember member);
    public signal void member_data_changed (Object sender, ProjectMember member);
    public signal void member_editor_created (ProjectMember member, Ui.Editor editor);

    public string build_absolute_path(string relpath) {
      if (GLib.Path.is_absolute(relpath))
        return relpath;
      else
        return GLib.Path.build_filename(this.basepath,relpath);
    }

    public void load (string filename) throws ProjectError {

      this.basepath = GLib.Path.get_dirname(filename);
      this.filename = GLib.Path.get_basename(filename);
      //GLib.Environment.set_current_dir(this.basepath);

      // Load document
      Xml.Doc* doc = Xml.Parser.parse_file (this.build_absolute_path(this.filename));
      if (doc == null)
        throw new ProjectError.FILE(_("Project file not found or permissions missing"));

      Xml.Node* root = doc->get_root_element ();
      if (root == null)
        throw new ProjectError.FILE(_("Project file empty"));
      
      // Check file format version
      string format_version = null;
      id = null;
      for (Xml.Attr* prop = root->properties; prop != null; prop = prop->next) {
        if (prop->name == "format_version")
          format_version = prop->children->content;
        else if (prop->name == "project_id")
          id = prop->children->content;
      }
      
      if (format_version == null)
        throw new ProjectError.VERSION (_("Project file format version missing"));
      if (int.parse(format_version) > 1)
        throw new ProjectError.VERSION (_("Project file format newer than supported"));
      
      if (id == null)
        throw new ProjectError.FILE (_("Project ID missing"));
      
      // Iterate first level of project file, pass on to project members
      for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;

        var memberType = EnumProjectMember.fromString (iter->name);
        var member = ProjectMemberFactory.createMember (memberType, this);
        if (member != null) {
          member.load (iter);
          members.add (member);
        }
      }
      delete doc;
    }
    
    public ProjectMember? getMemberFromId (string id) {
      foreach (var member in members) {
        if (member.id == id)
          return member;
      }
      return null;
    }
    
    public void createMember (EnumProjectMember type) {
      var new_member = ProjectMemberFactory.createMember(type, this);
      // Find new unique ID
      int cnt = 0;
      while (true) {
        cnt ++;
        bool found = false;
        foreach (var member in members)
          if (member.id == cnt.to_string()) {
            found = true;
            break;
          }
        if (!found)
          break;
      }
      new_member.id = cnt.to_string();
      // Add member if created successfully
      if (!new_member.create())
        return;
      
      members.add (new_member);
      member_added (new_member);
    }
    public void removeMember (ProjectMember member) {
      members.remove (member);
      member_removed (member);
    }

    public void save () {
      var writer = new Xml.TextWriter.filename (this.build_absolute_path(this.filename));
      writer.set_indent (true);
      writer.set_indent_string ("\t");

      writer.start_document ();
      writer.start_element ("project");
      writer.write_attribute ("format_version", "1");
      writer.write_attribute ("project_id", id);
      
      foreach (ProjectMember member in members) {
        member.save (writer);
      }
      
      writer.end_element();
      writer.end_document();

      writer.flush();
    }
  
  }

} 

