namespace Project {
  public class ProjectMemberValaSource : ProjectMember {

    public FileRef file = null;
    public Gtk.SourceBuffer buffer = new Gtk.SourceBuffer(null);

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.VALASOURCE;
    }

    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "filename")
          file = new FileRef.from_rel (project, prop->children->content);
      }
      if (file == null)
        throw new ProjectError.CORRUPT_MEMBER(_("filename attribute missing in valasource member"));
      // Load file content
      string content = null;
      FileUtils.get_contents (file.get_abs(), out content);
      buffer.begin_not_undoable_action();
      buffer.text = content;
      buffer.end_not_undoable_action();
    }

    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("filename", file.get_rel());
    }

    public override bool create () {
      var file_chooser = new Gtk.FileChooserDialog ("Open File", null,
                                    Gtk.FileChooserAction.OPEN,
                                    _("_Cancel"), Gtk.ResponseType.CANCEL,
                                     _("_Open"), Gtk.ResponseType.ACCEPT);
      if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
        var projectfolder = File.new_for_path (project.filename).get_parent();
        file = new FileRef.from_file (project, file_chooser.get_file());

        string content = null;
        // Set initial buffer content
        FileUtils.get_contents (file.get_abs(), out content);
        buffer.begin_not_undoable_action();
        buffer.text = content;
        buffer.end_not_undoable_action();
      }
      file_chooser.destroy ();
      return file != null;
    }

    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorValaSource(this, main_widget);
    }

    public override string getTitle() {
      return file.get_rel();
    }
  }
}
