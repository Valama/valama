namespace Project {
  public class ProjectMemberGladeUi : ProjectMember {

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.GLADEUI;
    }

    public FileRef file = null;

    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "filename")
          file = new FileRef.from_rel (project, prop->children->content);
      }
      if (file == null)
        throw new ProjectError.CORRUPT_MEMBER(_("filename attribute missing in GladeUi member"));
      // Load file content
    }

    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("filename", file.get_rel());
    }

    public override bool create () {
      var file_chooser = new Gtk.FileChooserDialog ("Open File", null,
                                    Gtk.FileChooserAction.OPEN,
                                    Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                    Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
      if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
        var projectfolder = File.new_for_path (project.filename).get_parent();
        file = new FileRef.from_file (project, file_chooser.get_file());
      }
      file_chooser.destroy ();
      return file != null;
    }

    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorGladeUi(this, main_widget);
    }

    public override string getTitle() {
      return file.get_rel();
    }
  }

}
