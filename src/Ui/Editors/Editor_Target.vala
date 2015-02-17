using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Target.glade")]
  private class TargetTemplate : Box {
  	[GtkChild]
  	public ListBox sources_list;
  	[GtkChild]
  	public ListBox deps_list;
  	[GtkChild]
  	public ToolButton btn_add;
  	[GtkChild]
  	public ToolButton btn_remove;
  	[GtkChild]
  	public ToolButton btn_edit;
  	[GtkChild]
  	public Entry ent_binary_name;
  	[GtkChild]
  	public ComboBoxText combo_buildsystem;
  }
  public class EditorTarget : Editor {

    private TargetTemplate template = new TargetTemplate();

    public EditorTarget(Project.ProjectMemberTarget member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      title = "Target";

      // Fill buildsystem combo and keep it in sync
      foreach (var i in Builder.EnumBuilder.to_array())
        template.combo_buildsystem.append (i.toString(), i.toString());
      template.combo_buildsystem.set_active_id (member.builder.toString());

      template.combo_buildsystem.changed.connect (()=>{
        member.builder = Builder.EnumBuilder.fromString(template.combo_buildsystem.get_active_id());
      });

      // Keep sources list in sync
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

      // Keep binary name entry in sync
      template.ent_binary_name.text = member.binary_name;
      template.ent_binary_name.changed.connect (()=>{
        member.binary_name = template.ent_binary_name.text;
        member.project.member_data_changed (this, member);
      });
      
      widget = template;
      
      // Initial list update
      update_sources_list();
      setup_dependencies_list();
    }
    

    // Sources list
    // ============
    
    private inline void update_sources_list() {
      foreach (Gtk.Widget widget in template.sources_list.get_children())
        template.sources_list.remove (widget);

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
          main_widget.project.member_data_changed (this, my_member);
        });
        
        row.add (check);
        template.sources_list.add (row);
      }
      template.sources_list.show_all();
    }

    // Dependencies list
    // =================

    private inline void setup_dependencies_list() {

      template.btn_add.clicked.connect (() => {
        var my_member = member as Project.ProjectMemberTarget;
        var new_dep = new Project.MetaDependency();
        new_dep.name = "New dependency";
        my_member.metadependencies.add (new_dep);
        update_dependencies_list ();
      });

      template.btn_remove.clicked.connect (() => {
        if (template.deps_list.get_selected_row() == null)
          return;
        var my_member = member as Project.ProjectMemberTarget;
        var dep = template.deps_list.get_selected_row().get_data<Project.MetaDependency>("metadependency");
        my_member.metadependencies.remove (dep);
        update_dependencies_list ();
      });

      template.btn_edit.clicked.connect (() => {
        if (template.deps_list.get_selected_row() == null)
          return;

        var dep = template.deps_list.get_selected_row().get_data<Project.MetaDependency>("metadependency");
        dep.show_edit_dialog();
        update_dependencies_list ();
      });

      template.deps_list.row_selected.connect(dependencies_list_row_selected);
      update_dependencies_list();
    }
    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {

    }
    private void dependencies_list_row_selected (Gtk.ListBoxRow? row) {
      template.btn_remove.sensitive = row != null;
      template.btn_edit.sensitive = row != null;
    }

    private inline void update_dependencies_list() {
      foreach (Gtk.Widget widget in template.deps_list.get_children())
        template.deps_list.remove (widget);

      var my_member = member as Project.ProjectMemberTarget;

      foreach (var metadep in my_member.metadependencies) {
        var row = new Gtk.ListBoxRow();
        row.set_data<Project.MetaDependency> ("metadependency", metadep);
        row.add (new Gtk.Label(metadep.name));
        template.deps_list.add (row);
      }
      template.deps_list.show_all();
    }

    internal override void destroy_internal() {

    }

  }

}
