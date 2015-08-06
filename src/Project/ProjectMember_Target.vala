namespace Project {
  public class ProjectMemberTarget : ProjectMember {

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.TARGET;
    }

    public Builder.Builder builder = null;

    public signal void builder_changed();
    private Builder.EnumBuildsystem _buildsystem;
    public Builder.EnumBuildsystem buildsystem {
      get { return _buildsystem; }
      set {
        if (value != _buildsystem || builder == null) {
          builder = Builder.BuilderFactory.create_member (value, this);
          builder_changed();
        }
        _buildsystem = value;
      }
    }

    public string binary_name = null;
    
    public Gee.ArrayList<string> included_sources = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> included_gresources = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> included_data = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> included_gladeuis = new Gee.ArrayList<string>();
  
    public Gee.LinkedList<MetaDependency> metadependencies = new Gee.LinkedList<MetaDependency>();

    public Gee.LinkedList<Define> defines = new Gee.LinkedList<Define>();

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
        if (iter->name == "gresource") {
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
            if (prop->name == "id")
              included_gresources.add(prop->children->content);
          }
        }
        if (iter->name == "data") {
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
            if (prop->name == "id")
              included_data.add(prop->children->content);
          }
        }
        if (iter->name == "gladeui") {
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
            if (prop->name == "id")
              included_gladeuis.add(prop->children->content);
          }
        }
        if (iter->name == "metadependency") {
          var dep = new MetaDependency();
          dep.load (iter);
          metadependencies.add (dep);
        }
        if (iter->name == "define") {
          var def = new Define();
          def.load (iter);
          defines.add (def);
        }
        if (iter->name == "buildsystem") {
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
            if (prop->name == "type")
              buildsystem = Builder.EnumBuildsystem.fromString(prop->children->content);
          builder.load (iter);
        }
      }
      if (binary_name == null)
        throw new ProjectError.CORRUPT_MEMBER(_("binary_name attribute missing in target member"));
      // Handle removed sources
      project.member_removed.connect ((member)=>{
        if (member is ProjectMemberValaSource) {
          var member_source = member as ProjectMemberValaSource;
          if (member_source.id in included_sources) {
            included_sources.remove (member_source.id);
            project.member_data_changed (this, this);
          }
        } else if (member is ProjectMemberGResource) {
          var member_gresource = member as ProjectMemberGResource;
          if (member_gresource.id in included_gresources) {
            included_gresources.remove (member_gresource.id);
            project.member_data_changed (this, this);
          }
        } else if (member is ProjectMemberData) {
          var member_data = member as ProjectMemberData;
          if (member_data.id in included_data) {
            included_data.remove (member_data.id);
            project.member_data_changed (this, this);
          }
        }
      });
    }
    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("binary_name", binary_name);
      writer.start_element ("buildsystem");
      writer.write_attribute ("type", buildsystem.toString());
      builder.save (writer);
      writer.end_element();
      foreach (string source_id in included_sources) {
        writer.start_element ("source");
        writer.write_attribute ("id", source_id);
        writer.end_element();
      }
      foreach (string gresource_id in included_gresources) {
        writer.start_element ("gresource");
        writer.write_attribute ("id", gresource_id);
        writer.end_element();
      }
      foreach (string data_id in included_data) {
        writer.start_element ("data");
        writer.write_attribute ("id", data_id);
        writer.end_element();
      }
      foreach (string gladeui_id in included_gladeuis) {
        writer.start_element ("gladeui");
        writer.write_attribute ("id", gladeui_id);
        writer.end_element();
      }
      foreach (var dep in metadependencies) {
        writer.start_element ("metadependency");
        dep.save (writer);
        writer.end_element();
      }
      foreach (var def in defines) {
        writer.start_element ("define");
        def.save (writer);
        writer.end_element();
      }
    }
    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorTarget(this, main_widget);
    }
    public override string getTitle() {
      return binary_name;
    }
  }

}

