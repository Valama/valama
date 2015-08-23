namespace Project {

  public abstract class ProjectMember : Object {
  
    public string id = null;
    public abstract EnumProjectMember get_project_member_type();
    public Project project;
    public Search.SearchProvider? search_provider = null;

    public void load (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "id")
          id = prop->children->content;
      }
      if (id == null)
        throw new ProjectError.CORRUPT_MEMBER(_("id attribute missing in member"));
      load_internal (node);
    }

    public void save (Xml.TextWriter writer) {
      writer.start_element (get_project_member_type().toString());
      writer.write_attribute ("id", id);
      save_internal (writer);
      writer.end_element();
    }

    internal abstract void load_internal (Xml.Node* node) throws ProjectError;

    internal abstract void save_internal (Xml.TextWriter writer);
    
    internal abstract Ui.Editor createEditor_internal(Ui.MainWidget main_widget);

    public Ui.Editor? createEditor(Ui.MainWidget main_widget) {
      if (editor != null) {
        return null;
      }
      editor = createEditor_internal (main_widget);
      editor.destroyed.connect (()=>{
        editor = null;
      });
      project.member_editor_created (this, editor);
      return editor;
    }

    public Ui.Editor editor {public get; private set; default = null;}

    public abstract string getTitle();
  }

} 
