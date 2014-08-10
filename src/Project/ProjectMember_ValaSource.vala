namespace Project {
  public class ProjectMemberValaSource : ProjectMember {
  
    public string filename = null;
    
    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "filename")
          filename = prop->children->content;
      }
      if (filename == null)
        throw new ProjectError.CORRUPT_MEMBER("filename attribute missing in valasource member");
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
    public override Ui.Editor createEditor() {
      return new Ui.EditorValaSource(this);
    }
    public override string getTitle() {
      return filename;
    }
  }

}
