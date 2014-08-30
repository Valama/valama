namespace Ui {

  public class ErrorList : Element {
  
    private Gtk.ListBox list;
    
    private Gtk.Revealer revealer;
  
    public override void init() {
      //var grid = new Gtk.Grid();

      // Build list of members
      list = new Gtk.ListBox();
      
      //list.row_selected.connect(row_selected);
      
      //main_widget.project.member_added.connect(()=>{fill_list();});
      //main_widget.project.member_removed.connect(()=>{fill_list();});

      var scrw_list = new Gtk.ScrolledWindow (null, null);
      scrw_list.add (list);
      scrw_list.show_all();
      //scrw_list.vexpand = true;
      scrw_list.set_size_request (200, 200);
      //grid.attach (scrw_list, 0, 0, 1, 1);
      
      // Build toolbar
      /*var toolbar = new Gtk.Toolbar();
      toolbar.icon_size = Gtk.IconSize.MENU;
      
      btn_add = new Gtk.ToolButton (null, null);
      btn_add.icon_name = "list-add-symbolic";
      btn_add.clicked.connect (() => {
        //main_widget.project.createMember (Project.EnumProjectMember.VALASOURCE);
      });
      //btn_add.sensitive = false;
      toolbar.add (btn_add);

      btn_remove = new Gtk.ToolButton (null, null);
      btn_remove.icon_name = "list-remove-symbolic";
      btn_remove.clicked.connect (() => {
        //main_widget.project.removeMember (list.get_selected_row().get_data<Project.ProjectMember>("member"));
      });
      //btn_add.sensitive = false;
      toolbar.add (btn_remove);

      
      grid.attach (toolbar, 0, 1, 1, 1);*/
      
      revealer = new Gtk.Revealer();
      revealer.add (scrw_list);
      //revealer.add (list);
      revealer.show_all();
      //revealer.set_reveal_child (true);
      widget = revealer;
      
      main_widget.code_context_provider.context_updated.connect (update);
      update();
    }

    private void update() {
      var report = main_widget.code_context_provider.report;
      revealer.set_reveal_child (report.errlist.size != 0);

      foreach (Gtk.Widget widget in list.get_children())
        list.remove (widget);
      foreach (var error in report.errlist) {
        var row = new Gtk.ListBoxRow();
        var label = new Gtk.Label(error.message);
        
        row.activate.connect(()=>{
          if (error.source == null)
            return;
          string myfilename = error.source.file.get_relative_filename();
          var editor = get_editor_by_file (myfilename);
          editor.jump_to_sourceref (error.source);
        });
        row.add (label);
        list.add (row);
      }
      list.show_all();
    }

    private Ui.EditorValaSource get_editor_by_file (string filename) {
      var member = get_source_member_by_file (filename);
      main_widget.editor_viewer.openMember (member);
      return member.editor as Ui.EditorValaSource;
    }

    private Project.ProjectMemberValaSource get_source_member_by_file (string filename) {
      // Find project member
      Project.ProjectMemberValaSource source_member = null;
      foreach (var member in main_widget.project.members)
        if (member is Project.ProjectMemberValaSource) {
          source_member = member as Project.ProjectMemberValaSource;
          if (source_member.filename == filename)
            break;
        }
      return source_member;
    }

    public override void destroy() {
    
    }
  }

}
