using Project;

namespace Ui {

  namespace ProjectMemberCreator {

    private string vala_source_dir = null;

    public static ProjectMember? createValaSourceOpen(Project.Project project) {
      var member = new ProjectMemberValaSource();
      member.project = project;

      var file_chooser = new Gtk.FileChooserDialog ("Open File", null,
                                    Gtk.FileChooserAction.OPEN,
                                    _("_Cancel"), Gtk.ResponseType.CANCEL,
                                     _("_Open"), Gtk.ResponseType.ACCEPT);
      if (vala_source_dir != null)
        file_chooser.set_current_folder(vala_source_dir);
      if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
        vala_source_dir = file_chooser.get_current_folder();

        member.file = new FileRef.from_file (project, file_chooser.get_file());

        string content = null;
        // Set initial buffer content
        FileUtils.get_contents (member.file.get_abs(), out content);
        member.buffer.begin_not_undoable_action();
        member.buffer.text = content;
        member.buffer.end_not_undoable_action();
      }
      file_chooser.destroy ();
      if (member.file == null)
        return null;
      return member;
    }

    private string vala_source_new_dir = null;

    public static ProjectMember? createValaSourceNew(Project.Project project) {
      var member = new ProjectMemberValaSource();
      member.project = project;

      var file_chooser = new Gtk.FileChooserDialog ("New File", null,
                                    Gtk.FileChooserAction.SAVE,
                                    _("_Cancel"), Gtk.ResponseType.CANCEL,
                                     _("_Save"), Gtk.ResponseType.ACCEPT);
      if (vala_source_new_dir != null)
        file_chooser.set_current_folder(vala_source_new_dir);
      if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
        vala_source_new_dir = file_chooser.get_current_folder();

        member.file = new FileRef.from_file (project, file_chooser.get_file());
        if (!file_chooser.get_file().query_exists())
          FileUtils.set_contents (member.file.get_abs(), "");
        else
          member.file = null;
      }
      file_chooser.destroy ();
      if (member.file == null)
        return null;
      return member;
    }

  }

}
