namespace Ui {

  public class EditorInfo : Editor {
  
    public EditorInfo(Project.ProjectMemberInfo member) {
      this.member = member;
      title = "Info";
      
      var txt_name = new Gtk.Entry();
      txt_name.text = member.name;
      txt_name.changed.connect (()=>{
        member.name = txt_name.text;
        member.project.member_data_changed (this, member);
      });
      
      var spn_version_major = new Gtk.SpinButton.with_range(0,1000,1);
      spn_version_major.value = member.major;
      spn_version_major.value_changed.connect(()=>{
        member.major = (int)spn_version_major.value;
        member.project.member_data_changed (this, member);
      });
      var spn_version_minor = new Gtk.SpinButton.with_range(0,1000,1);
      spn_version_minor.value = member.minor;
      spn_version_minor.value_changed.connect(()=>{
        member.minor = (int)spn_version_minor.value;
        member.project.member_data_changed (this, member);
      });
      var spn_version_patch = new Gtk.SpinButton.with_range(0,1000,1);
      spn_version_patch.value = member.patch;
      spn_version_patch.value_changed.connect(()=>{
        member.patch = (int)spn_version_patch.value;
        member.project.member_data_changed (this, member);
      });
      
      
      var grid = new Gtk.Grid();
      grid.attach (descriptionLabel("Project name"), 0, 0, 1, 1);
      grid.attach (txt_name, 1, 0, 3, 1);
      grid.attach (descriptionLabel("Version"), 0, 1, 1, 1);
      grid.attach (spn_version_major, 1, 1, 1, 1);
      grid.attach (spn_version_minor, 2, 1, 1, 1);
      grid.attach (spn_version_patch, 3, 1, 1, 1);
      

      grid.show_all();
      widget = grid;
    }
    
    private inline Gtk.Label descriptionLabel (string text) {
      var label = new Gtk.Label (text);
      label.xalign = 1.0f;
      return label;
    }
    public override void dispose() {
    
    }
  }

}
