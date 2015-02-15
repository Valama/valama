using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Info.glade")]
  private class ProjectInfoTemplate : Box {
  	[GtkChild]
  	public ListBox listbox_authors;
  	[GtkChild]
  	public ToolButton tb_add;
  	[GtkChild]
  	public ToolButton tb_remove;
  	[GtkChild]
  	public SpinButton spn_version_patch;
  	[GtkChild]
  	public SpinButton spn_version_minor;
  	[GtkChild]
  	public SpinButton spn_version_major;
  	[GtkChild]
  	public Entry ent_name;
  }

  public class EditorInfo : Editor {

    private ProjectInfoTemplate template = new ProjectInfoTemplate();

    public EditorInfo(Project.ProjectMemberInfo member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      title = "Info";
      
      template.ent_name.text = member.name;
      template.ent_name.changed.connect (()=>{
        member.name = template.ent_name.text;
        member.project.member_data_changed (this, member);
      });
      
      template.spn_version_major.value = member.major;
      template.spn_version_major.value_changed.connect(()=>{
        member.major = (int)template.spn_version_major.value;
        member.project.member_data_changed (this, member);
      });

      template.spn_version_minor.value = member.minor;
      template.spn_version_minor.value_changed.connect(()=>{
        member.minor = (int)template.spn_version_minor.value;
        member.project.member_data_changed (this, member);
      });

      template.spn_version_patch.value = member.patch;
      template.spn_version_patch.value_changed.connect(()=>{
        member.patch = (int)template.spn_version_patch.value;
        member.project.member_data_changed (this, member);
      });

      widget = template;
    }
    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {

    }
    private inline Gtk.Label descriptionLabel (string text) {
      var label = new Gtk.Label (text);
      label.xalign = 1.0f;
      return label;
    }
    internal override void destroy_internal() {
    
    }
  }

}

