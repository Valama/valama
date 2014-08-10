namespace Project {
  public class ProjectMemberTarget : ProjectMember {
  
    public string binary_name = null;
    
    public Gee.ArrayList<string> included_sources = new Gee.ArrayList<string>();
  
    public Gee.LinkedList<MetaDependency> metadependencies = new Gee.LinkedList<MetaDependency>();

    internal override void load_internal (Xml.Node* node) throws ProjectError {
      // Read binary name
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "binary_name")
          binary_name = prop->children->content;
      }
      // Read active source id's
      for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;
        if (iter->name == "source") {
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
            if (prop->name == "id")
              included_sources.add(prop->children->content);
          }
        }
        if (iter->name == "metadependency") {
          var dep = new MetaDependency();
          dep.load (iter);
          metadependencies.add (dep);
        }
      }
      if (binary_name == null)
        throw new ProjectError.CORRUPT_MEMBER("binary_name attribute missing in target member");
      // Handle removed sources
      project.member_removed.connect ((member)=>{
        if (member is ProjectMemberValaSource) {
          var member_source = member as ProjectMemberValaSource;
          if (member_source.id in included_sources) {
            included_sources.remove (member_source.id);
            member.project.member_data_changed (this, this);
          }
        }
      });
    }
    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("buildsystem", "valama");
      writer.write_attribute ("binary_name", binary_name);
      foreach (string source_id in included_sources) {
        writer.start_element ("source");
        writer.write_attribute ("id", source_id);
        writer.end_element();
      }
      foreach (var dep in metadependencies) {
        writer.start_element ("metadependency");
        dep.save (writer);
        writer.end_element();
      }
    }
    public override bool create () {
      return false;
    }
    public override Ui.Editor createEditor() {
      return new Ui.EditorTarget(this);
    }
    public override string getTitle() {
      return binary_name;
    }
  }

}
