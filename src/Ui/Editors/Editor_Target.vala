namespace Ui {

  public class EditorTarget : Editor {
  
    public EditorTarget(Project.ProjectMemberTarget member) {
      this.member = member;
      title = "Target";

      member.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberValaSource)
          update_sources_list();
      });
      member.project.member_removed.connect ((member)=>{
        if (member is Project.ProjectMemberValaSource)
          update_sources_list();
      });
      member.project.member_data_changed.connect((sender, mb)=>{
        if (mb != member) return;
        if (sender == this) return;
        update_sources_list();
      });

      var grid = new Gtk.Grid();


      var txt_bin_name = new Gtk.Entry();
      txt_bin_name.text = member.binary_name;
      txt_bin_name.changed.connect (()=>{
        member.binary_name = txt_bin_name.text;
        member.project.member_data_changed (this, member);
      });
      
      grid.attach (new Gtk.Label ("Binary name"), 0, 0, 1, 1);
      grid.attach (txt_bin_name, 1, 0, 1, 1);
      
      grid.attach (new Gtk.Label ("Active sources"), 0, 1, 1, 1);
      grid.attach (build_sources_list(), 0, 2, 2, 1);
      grid.show();
      
      grid.show_all();
      widget = grid;
    }
    
    private Gtk.ListBox sources_list;
    private inline Gtk.Widget build_sources_list() {
      sources_list = new Gtk.ListBox();
      sources_list.selection_mode = Gtk.SelectionMode.NONE;
      
      update_sources_list();

      var scrw_list = new Gtk.ScrolledWindow (null, null);
      scrw_list.add (sources_list);
      scrw_list.hexpand = true;
      scrw_list.vexpand = true;
      return scrw_list;
    }
    
    private inline void update_sources_list() {
      foreach (Gtk.Widget widget in sources_list.get_children())
        sources_list.remove (widget);

      var my_member = member as Project.ProjectMemberTarget;
      
      foreach (Project.ProjectMember m in my_member.project.members) {
        if (!(m is Project.ProjectMemberValaSource))
          continue;
        
        var row = new Gtk.ListBoxRow();
        var check = new Gtk.CheckButton();
        check.active = m.id in my_member.included_sources;
        check.label = (m as Project.ProjectMemberValaSource).filename;
        check.toggled.connect(()=>{
          if (check.active)
            my_member.included_sources.add (m.id);
          else
            my_member.included_sources.remove (m.id);
        });
        
        row.add (check);
        sources_list.add (row);
      }
      sources_list.show_all();
    }
    
    public override void dispose() {
    
    }
  
  }

}
