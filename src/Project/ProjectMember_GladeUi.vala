namespace Project {
  public class ProjectMemberGladeUi : ProjectMember {

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.GLADEUI;
    }

    public string filename = null;
    public string full_filename = null;

    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "filename")
          filename = prop->children->content;
      }
      if (filename == null)
        throw new ProjectError.CORRUPT_MEMBER(_("filename attribute missing in GladeUi member"));
      if (this.project != null)
        this.full_filename = this.project.build_absolute_path(this.filename);
      else
        this.full_filename = this.filename;

      // Load file content using full_filename
    }

    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("filename", filename);
    }
    public override bool create () {
      var file_chooser = new Gtk.FileChooserDialog ("Open File", null,
                                    Gtk.FileChooserAction.OPEN,
                                    Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                    Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
      if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
        var projectfolder = File.new_for_path (project.filename).get_parent();
        filename = projectfolder.get_relative_path (file_chooser.get_file());
      }
      file_chooser.destroy ();
      return filename != null;
    }
    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorGladeUi(this, main_widget);
    }
    public override string getTitle() {
      return filename;
    }
  }

}
