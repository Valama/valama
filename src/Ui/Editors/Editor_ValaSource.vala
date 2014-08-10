namespace Ui {

  public class EditorValaSource : Editor {
  
    public EditorValaSource(Project.ProjectMemberValaSource member) {
      this.member = member;
      title = member.filename;
      widget = new Gtk.Label ("Source");
      widget.show_all();
    }
    public override void dispose() {
    
    }
  }

}
