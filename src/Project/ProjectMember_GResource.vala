namespace Project {

  public class GResource {

    public FileRef file = null;
    public bool compressed;
    public bool xml_stripblanks;

    public void load (Xml.Node* node, Project project) {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "file")
          file = new FileRef.from_rel (project, prop->children->content);
        else if (prop->name == "compressed")
          compressed = prop->children->content == "true";
        else if (prop->name == "xml_stripblanks")
          xml_stripblanks = prop->children->content == "true";
      }
    }

    public void save (Xml.TextWriter writer) {
      writer.write_attribute ("file", file.get_rel());
      writer.write_attribute ("compressed", compressed.to_string());
      writer.write_attribute ("xml_stripblanks", xml_stripblanks.to_string());
    }

  }

  public class ProjectMemberGResource : ProjectMember {

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.GRESOURCE;
    }

    public string name;

    public Gee.LinkedList<GResource> resources = new Gee.LinkedList<GResource>();

    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "name")
          name = prop->children->content;
      }
      // Read resources
      for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;
        if (iter->name == "resource") {
          var res = new GResource();
          res.load (iter,this.project);
          resources.add (res);
        }
      }
    }

    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("name", name);
      foreach (var res in resources) {
        writer.start_element ("resource");
        res.save (writer);
        writer.end_element();
      }
    }

    public override bool create () {
      name = "New resource";
      return true;
    }

    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorGResource(this, main_widget);
    }

    public override string getTitle() {
      return name;
    }
  }
}

