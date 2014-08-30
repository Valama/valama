namespace Ui {

  public class EditorTarget : Editor {
  
    public EditorTarget(Project.ProjectMemberTarget member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
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

      grid.attach (new Gtk.Label ("Dependencies"), 0, 3, 1, 1);
      grid.attach (build_dependencies_list(), 0, 4, 2, 1);
      grid.show();
      
      grid.show_all();
      widget = grid;
    }
    

    // Sources list
    // ============

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
          my_member.project.member_data_changed (this, my_member);
        });
        
        row.add (check);
        sources_list.add (row);
      }
      sources_list.show_all();
    }

    // Dependencies list
    // =================

    Gtk.ToolButton dependencies_list_btn_remove = null;
    Gtk.ToolButton dependencies_list_btn_edit = null;
    private Gtk.ListBox dependencies_list;
    private inline Gtk.Widget build_dependencies_list() {
      dependencies_list = new Gtk.ListBox();

      var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

      var scrw_list = new Gtk.ScrolledWindow (null, null);
      scrw_list.add (dependencies_list);
      scrw_list.hexpand = true;
      scrw_list.vexpand = true;
      box.add (scrw_list);

      var toolbar = new Gtk.Toolbar();
      toolbar.icon_size = Gtk.IconSize.MENU;

      var btn_add = new Gtk.ToolButton (null, null);
      btn_add.icon_name = "list-add-symbolic";
      btn_add.clicked.connect (() => {
        var my_member = member as Project.ProjectMemberTarget;
        var new_dep = new Project.MetaDependency();
        new_dep.name = "New dependency";
        my_member.metadependencies.add (new_dep);
        update_dependencies_list ();
      });
      toolbar.add (btn_add);

      dependencies_list_btn_remove = new Gtk.ToolButton (null, null);
      dependencies_list_btn_remove.icon_name = "list-remove-symbolic";
      dependencies_list_btn_remove.clicked.connect (() => {
        if (dependencies_list.get_selected_row() == null)
          return;
        var my_member = member as Project.ProjectMemberTarget;
        var dep = dependencies_list.get_selected_row().get_data<Project.MetaDependency>("metadependency");
        my_member.metadependencies.remove (dep);
        update_dependencies_list ();
      });
      toolbar.add (dependencies_list_btn_remove);

      dependencies_list_btn_edit = new Gtk.ToolButton (null, null);
      dependencies_list_btn_edit.icon_name = "emblem-system-symbolic";
      dependencies_list_btn_edit.clicked.connect (() => {
        if (dependencies_list.get_selected_row() == null)
          return;

        var dep = dependencies_list.get_selected_row().get_data<Project.MetaDependency>("metadependency");
        dep.show_edit_dialog();
        update_dependencies_list ();
      });
      toolbar.add (dependencies_list_btn_edit);

      box.add (toolbar);

      box.show_all();
      dependencies_list.row_selected.connect(dependencies_list_row_selected);
      update_dependencies_list();
      return box;
    }
    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {

    }
    private void dependencies_list_row_selected (Gtk.ListBoxRow? row) {
      dependencies_list_btn_remove.sensitive = row != null;
      dependencies_list_btn_edit.sensitive = row != null;
    }

    private inline void update_dependencies_list() {
      foreach (Gtk.Widget widget in dependencies_list.get_children())
        dependencies_list.remove (widget);

      var my_member = member as Project.ProjectMemberTarget;

      foreach (var metadep in my_member.metadependencies) {
        var row = new Gtk.ListBoxRow();
        row.set_data<Project.MetaDependency> ("metadependency", metadep);
        row.add (new Gtk.Label(metadep.name));
        dependencies_list.add (row);
      }
      dependencies_list.show_all();
    }

    internal override void destroy_internal() {

    }

  }

}
