namespace Ui {

  public class ProjectStructure : Element {
  
    public Gtk.Widget widget;
  
    private Gtk.ListBox list;
    
    private Gtk.ToolButton btn_add;
    private Gtk.ToolButton btn_remove;
  
    public override void init() {
      var grid = new Gtk.Grid();

      // Build list of members
      list = new Gtk.ListBox();
      
      fill_list();
      
      list.row_selected.connect(row_selected);
      
      main_widget.project.member_added.connect(()=>{fill_list();});
      main_widget.project.member_removed.connect(()=>{fill_list();});

      var scrw_list = new Gtk.ScrolledWindow (null, null);
      scrw_list.add (list);
      scrw_list.show_all();
      scrw_list.vexpand = true;
      scrw_list.set_size_request (200, 0);
      grid.attach (scrw_list, 1, 0, 1, 1);
      
      // Build toolbar
      var toolbar = new Gtk.Toolbar();
      toolbar.icon_size = Gtk.IconSize.MENU;
      
      btn_add = new Gtk.ToolButton (null, null);
      btn_add.icon_name = "list-add-symbolic";
      btn_add.clicked.connect (() => {
        main_widget.project.createMember (Project.EnumProjectMember.VALASOURCE);
      });
      //btn_add.sensitive = false;
      toolbar.add (btn_add);

      btn_remove = new Gtk.ToolButton (null, null);
      btn_remove.icon_name = "list-remove-symbolic";
      btn_remove.clicked.connect (() => {
        main_widget.project.removeMember (list.get_selected_row().get_data<Project.ProjectMember>("member"));
      });
      //btn_add.sensitive = false;
      toolbar.add (btn_remove);

      
      toolbar.show_all();
      grid.attach (toolbar, 1, 1, 1, 1);
      
      grid.show();
      widget = grid;
    }
    
    private void row_selected (Gtk.ListBoxRow? row) {
      if (row == null) {
        btn_remove.sensitive = false;
        return;
      }
      var member = row.get_data<Project.ProjectMember>("member");
      btn_remove.sensitive = member is Project.ProjectMemberValaSource || member is Project.ProjectMemberTarget;
    }
    
    private void fill_list() {
      foreach (Gtk.Widget widget in list.get_children())
        list.remove (widget);
      foreach (Project.ProjectMember member in main_widget.project.members) {
      
        var row = new Gtk.ListBoxRow();
        var label = new Gtk.Label(member.getTitle());
        member.project.member_data_changed.connect((sender, mb)=>{
          if (mb == member)
            label.label = member.getTitle();
        });
        row.add (label);
        row.set_data<Project.ProjectMember> ("member", member);
        row.activate.connect(()=>{
          main_widget.editor_viewer.openMember(member);
        });
        list.add (row);
      }
      list.show_all();
    }
    
    public override void dispose() {
    
    }
  }

}
