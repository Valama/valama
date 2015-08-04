using Project;

namespace Ui {

  namespace ProjectMemberCreator {

    private string gladeui_dir = null;

    public static ProjectMember? createGladeUi(Project.Project project) {
      var member = new ProjectMemberGladeUi();
      member.project = project;

      var file_chooser = new Gtk.FileChooserDialog ("Open File", null,
                                    Gtk.FileChooserAction.OPEN,
                                    _("_Cancel"), Gtk.ResponseType.CANCEL,
                                     _("_Open"), Gtk.ResponseType.ACCEPT);
      if (gladeui_dir != null)
        file_chooser.set_current_folder(gladeui_dir);
      if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
        gladeui_dir = file_chooser.get_current_folder();

        var projectfolder = File.new_for_path (project.filename).get_parent();
        member.file = new FileRef.from_file (project, file_chooser.get_file());
      }
      file_chooser.destroy ();
      if (member.file == null)
        return null;
      return member;
    }

  }

}
