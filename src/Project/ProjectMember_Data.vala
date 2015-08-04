namespace Project {

  public class DataTarget {
    public string file = "";
    public string target = "";
    public bool is_folder = false;
    public void load (Xml.Node* node) {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "file")
          file = prop->children->content;
        else if (prop->name == "target")
          target = prop->children->content;
        else if (prop->name == "is_folder")
          is_folder = prop->children->content == "true";
      }
    }
    public void save (Xml.TextWriter writer) {
      writer.write_attribute ("file", file);
      writer.write_attribute ("target", target);
      writer.write_attribute ("is_folder", is_folder.to_string());
    }
  }

  public class ProjectMemberData : ProjectMember {

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.DATA;
    }

    public string name;
    public string basedir;

    public Gee.LinkedList<DataTarget> targets = new Gee.LinkedList<DataTarget>();

    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "name")
          name = prop->children->content;
        else if (prop->name == "basedir")
          basedir = prop->children->content;
      }
      // Read files
      for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;
        if (iter->name == "target") {
          var new_target = new DataTarget ();
          new_target.load (iter);
          targets.add (new_target);
        }
      }
    }
    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("name", name);
      writer.write_attribute ("basedir", basedir);
      foreach (var target in targets) {
        writer.start_element ("target");
        target.save (writer);
        writer.end_element();
      }
    }
    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorData(this, main_widget);
    }
    public override string getTitle() {
      return name;
    }
  }

}

