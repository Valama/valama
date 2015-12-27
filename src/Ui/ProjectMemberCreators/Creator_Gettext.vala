using Project;

namespace Ui {

  namespace ProjectMemberCreator {

    private string gettext_new_dir = null;

    public static ProjectMember? createGettextNew(Project.Project project) {
      var member = new ProjectMemberGettext();
      member.project = project;

      var file_chooser = new Gtk.FileChooserDialog ("New File", null,
                                    Gtk.FileChooserAction.SAVE,
                                    _("_Cancel"), Gtk.ResponseType.CANCEL,
                                     _("_Save"), Gtk.ResponseType.ACCEPT);
      if (gettext_new_dir != null)
        file_chooser.set_current_folder(gettext_new_dir);
      if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
        gettext_new_dir = file_chooser.get_current_folder();

        member.potfile = new FileRef.from_file (project, file_chooser.get_file());
        if (!file_chooser.get_file().query_exists())
          FileUtils.set_contents (member.potfile.get_abs(), "");
        else
          member.potfile = null;
      }
      file_chooser.destroy ();
      if (member.potfile == null)
        return null;
      return member;
    }

  }

}
