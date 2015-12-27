namespace Project {
  public class ProjectMemberGettext : ProjectMember {

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.GETTEXT;
    }

    public FileRef potfile = null;
    public string translation_name = "";
    public Gee.ArrayList<string> included_sources = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> included_gladeuis = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> languages = new Gee.ArrayList<string>();

    public File get_po_file (string language) {
      return File.new_for_path (potfile.get_abs()).get_parent().get_child(language + ".po");
    }

    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "potfile")
          potfile = new FileRef.from_rel (project, prop->children->content);
        if (prop->name == "translation_name")
          translation_name = prop->children->content;
      }

      // Read active source id's and supported languages
      for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;
        if (iter->name == "source") {
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
            if (prop->name == "id")
              included_sources.add(prop->children->content);
        }
        if (iter->name == "gladeui") {
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
            if (prop->name == "id")
              included_gladeuis.add(prop->children->content);
        }
        if (iter->name == "language") {
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
            if (prop->name == "id")
              languages.add(prop->children->content);
        }
      }

      // Handle removed members
      project.member_removed.connect ((member)=>{
        if (member is ProjectMemberValaSource) {
          var member_source = member as ProjectMemberValaSource;
          if (member_source.id in included_sources) {
            included_sources.remove (member_source.id);
            project.member_data_changed (this, this);
          }
        } else if (member is ProjectMemberGladeUi) {
          var member_gladeui = member as ProjectMemberGladeUi;
          if (member_gladeui.id in included_gladeuis) {
            included_gladeuis.remove (member_gladeui.id);
            project.member_data_changed (this, this);
          }
        }
      });

      if (potfile == null)
        throw new ProjectError.CORRUPT_MEMBER(_("potfile attribute missing in Gettext member"));
    }

    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("potfile", potfile.get_rel());
      writer.write_attribute ("translation_name", translation_name);
      foreach (string source_id in included_sources) {
        writer.start_element ("source");
        writer.write_attribute ("id", source_id);
        writer.end_element();
      }
      foreach (string gladeui_id in included_gladeuis) {
        writer.start_element ("gladeui");
        writer.write_attribute ("id", gladeui_id);
        writer.end_element();
      }
      foreach (string lang_id in languages) {
        writer.start_element ("language");
        writer.write_attribute ("id", lang_id);
        writer.end_element();
      }
    }

    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorGettext(this, main_widget);
    }

    public override string getTitle() {
      return potfile.get_rel();
    }
  }

}
