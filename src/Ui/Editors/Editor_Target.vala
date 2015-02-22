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
  	[GtkChild]
  	public Notebook notebook_settings;
  }
  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Target_Condition.glade")]
  private class ConditionEditorTemplate : ListBoxRow {
    public ConditionEditorTemplate(Ui.MainWidget main_widget, Project.Condition condition) {
      // Build library selection combo, activate current if found
      bool found = false;
      foreach (var lib in main_widget.installed_libraries_provider.installed_libraries) {
        cmb_library.append (lib.library, lib.library);
        if (lib.library == condition.library) {
          found = true;
          cmb_library.set_active_id (condition.library);
        }
      }
      if (!found && condition.library != "") {
        cmb_library.prepend (condition.library, condition.library);
        cmb_library.set_active_id (condition.library);
      }
      cmb_library.changed.connect (()=>{
        condition.library = cmb_library.get_active_text();
      });

      // Fill relation selector and keep in sync
      cmb_relation.append (Project.ConditionRelation.GREATER.toString(), ">");
      cmb_relation.append (Project.ConditionRelation.GREATER_EQUAL.toString(), ">=");
      cmb_relation.append (Project.ConditionRelation.EQUAL.toString(), "==");
      cmb_relation.append (Project.ConditionRelation.LESSER_EQUAL.toString(), "<=");
      cmb_relation.append (Project.ConditionRelation.LESSER.toString(), "<");
      cmb_relation.set_active_id (condition.relation.toString());
      cmb_relation.changed.connect (()=>{
        condition.relation = Project.ConditionRelation.fromString (cmb_relation.get_active_id());
      });

      // Keep version text in sync
      ent_version.text = condition.version;
      ent_version.changed.connect (()=>{
        condition.version = ent_version.text;
      });
    }
  	[GtkChild]
  	public ComboBoxText cmb_library;
  	[GtkChild]
  	public ComboBoxText cmb_relation;
  	[GtkChild]
  	public Button btn_remove;
  	[GtkChild]
  	public Entry ent_version;
  }
  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Target_Dependency.glade")]
  private class DependencyEditorTemplate : ListBoxRow {
    private Ui.MainWidget main_widget;
    private Project.Dependency dep;

    public DependencyEditorTemplate(Ui.MainWidget main_widget, Project.Dependency dep) {
      this.dep = dep;
      this.main_widget = main_widget;

      btn_add_condition.clicked.connect (()=>{
        var new_cond = new Project.Condition();
        dep.conditions.add (new_cond);
        update_list ();
      });

      update_list ();
    }

    private void update_list () {
      foreach (Gtk.Widget widget in list_conditions.get_children())
        list_conditions.remove (widget);
      foreach (var condition in dep.conditions) {
        var new_row = new ConditionEditorTemplate (main_widget, condition);
        list_conditions.add (new_row);

        // Handle removing a condition
        new_row.btn_remove.clicked.connect (()=>{
          dep.conditions.remove (condition);
          update_list();
        });
      }
      list_conditions.show_all();
    }

  	[GtkChild]
  	public Image img_type;
  	[GtkChild]
  	public Label lbl_title;
  	[GtkChild]
  	public ListBox list_conditions;
  	[GtkChild]
  	public Button btn_add_condition;
  }
  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Target_Meta_Dependency.glade")]
  private class MetaDependencyEditorTemplate : Box {

    private Project.MetaDependency meta_dep;
    private Ui.MainWidget main_widget;

    public MetaDependencyEditorTemplate(Ui.MainWidget main_widget, Project.MetaDependency meta_dep) {
      this.meta_dep = meta_dep;
      this.main_widget = main_widget;

      // Keep meta dep name in sync
      ent_name.text = meta_dep.name;
      ent_name.changed.connect (()=>{
        meta_dep.name = ent_name.text;
      });

      btn_add.clicked.connect (()=>{
        var new_dep = new Project.Dependency();
        meta_dep.dependencies.add (new_dep);
        update_list ();
      });
      btn_remove.clicked.connect (()=>{
        var selected_row = list_dependencies.get_selected_row();
        if (selected_row != null)
          meta_dep.dependencies.remove (selected_row.get_data<Project.Dependency>("dep"));
        update_list ();
      });

      update_list ();
    }
    
    private void update_list () {
      foreach (Gtk.Widget widget in list_dependencies.get_children())
        list_dependencies.remove (widget);
      foreach (var dep in meta_dep.dependencies) {
        var new_row = new DependencyEditorTemplate (main_widget, dep);
        new_row.set_data<Project.Dependency> ("dep", dep);
        list_dependencies.add (new_row);
      }
    }
 
  	[GtkChild]
  	public ListBox list_dependencies;
  	[GtkChild]
  	public ToolButton btn_add;
  	[GtkChild]
  	public ToolButton btn_remove;
  	[GtkChild]
  	public ToolButton btn_up;
  	[GtkChild]
  	public ToolButton btn_down;
  	[GtkChild]
  	public Entry ent_name;
  }

  public class EditorTarget : Editor {

    private TargetTemplate template = new TargetTemplate();

    public EditorTarget(Project.ProjectMemberTarget member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      title = "Target";

      // Fill buildsystem combo and keep it in sync
      foreach (var i in Builder.EnumBuildsystem.to_array())
        template.combo_buildsystem.append (i.toString(), i.toString());
      template.combo_buildsystem.set_active_id (member.buildsystem.toString());

      template.combo_buildsystem.changed.connect (()=>{
        member.buildsystem = Builder.EnumBuildsystem.fromString(template.combo_buildsystem.get_active_id());
        update_settings_ui();
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
      update_settings_ui();
    }
    
    // Buildsystem settings widget
    // ============

    Gtk.Widget settings_widget = null;
    private inline void update_settings_ui() {

      // Remove old page
      if (settings_widget != null) {
        var page_id = template.notebook_settings.page_num (settings_widget);
        if (page_id >= 0)
          template.notebook_settings.remove_page (page_id);
      }

      // Add settings page
      var my_member = member as Project.ProjectMemberTarget;
      settings_widget = my_member.builder.init_ui();
      if (settings_widget != null)
        template.notebook_settings.prepend_page (settings_widget, new Label ("Settings"));

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
        edit_meta_dependency (dep);
      });

      template.deps_list.row_selected.connect(dependencies_list_row_selected);
      update_dependencies_list();
    }

    private void edit_meta_dependency (Project.MetaDependency dep) {
      main_widget.installed_libraries_provider.update();

      var editor = new MetaDependencyEditorTemplate(main_widget, dep);

      var edit_dialog = new Dialog.with_buttons("", main_widget.window, DialogFlags.MODAL, "OK", ResponseType.OK);
      edit_dialog.get_content_area().add (editor);
      var ret = edit_dialog.run();
      edit_dialog.destroy();
      
      update_dependencies_list ();
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
