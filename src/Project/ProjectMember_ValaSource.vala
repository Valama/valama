namespace Project {

  public class ProjectMemberValaSource : ProjectMember {

    public string filename = null;
    public Gtk.SourceBuffer buffer = new Gtk.SourceBuffer(null);

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.VALASOURCE;
    }

    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "filename")
          filename = prop->children->content;
      }
      if (filename == null)
        throw new ProjectError.CORRUPT_MEMBER(_("filename attribute missing in valasource member"));
      if (this.project != null) {
        this.filename = this.project.build_absolute_path(this.filename);
      }
      // Load file content
      string content = null;
      FileUtils.get_contents (filename, out content);
      buffer.begin_not_undoable_action();
      buffer.text = content;
      buffer.end_not_undoable_action();
    }

    internal override void save_internal (Xml.TextWriter writer) {
      string final_path;
      if (this.project != null) {
        final_path = this.project.get_relative_path(this.filename);
      } else {
        final_path = this.filename;
      }
      writer.write_attribute ("filename", final_path);
    }
    public override bool create () {
      var file_chooser = new Gtk.FileChooserDialog ("Open File", null,
                                    Gtk.FileChooserAction.OPEN,
                                    Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                    Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
      if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
        var projectfolder = File.new_for_path (project.filename).get_parent();
        filename = projectfolder.get_relative_path (file_chooser.get_file());

        string content = null;
        // Set initial buffer content
        FileUtils.get_contents (filename, out content);
        buffer.begin_not_undoable_action();
        buffer.text = content;
        buffer.end_not_undoable_action();
      }
      file_chooser.destroy ();
      return filename != null;
    }
    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorValaSource(this, main_widget);
    }
    public override string getTitle() {
      return GLib.Path.get_basename(this.filename);
    }
  }

}
