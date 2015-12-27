using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Target_Define.glade")]
  private class DefineEditorTemplate : Box {

    private Project.Define define;
    private Ui.MainWidget main_widget;

    public DefineEditorTemplate(Ui.MainWidget main_widget, Project.Define define) {
      this.define = define;
      this.main_widget = main_widget;

      // Keep meta dep name in sync
      ent_name.text = define.define;
      ent_name.changed.connect (()=>{
        define.define = ent_name.text;
      });

      btn_add.clicked.connect (()=>{
        var new_cond = new Project.Condition();
        define.conditions.add (new_cond);
        update_list ();
      });

      update_list ();
    }
    private void update_list () {
      foreach (Gtk.Widget widget in list_conditions.get_children())
        list_conditions.remove (widget);
      foreach (var condition in define.conditions) {
        var new_row = new ConditionEditorTemplate (main_widget, condition);
        new_row.btn_remove.clicked.connect (()=>{
          define.conditions.remove (condition);
          update_list ();
        });
        list_conditions.add (new_row);
      }
    }
 
    [GtkChild]
    public ListBox list_conditions;
    [GtkChild]
    public ToolButton btn_add;
    [GtkChild]
    public Entry ent_name;
  }

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Target_NewDependency.glade")]
  private class NewDependencyDialogTemplate : Box {
    File projectfolder;
    public NewDependencyDialogTemplate (MainWidget main_widget) {
      projectfolder = File.new_for_path (main_widget.project.filename).get_parent();
      rbtn_package.sensitive = false;
      foreach (var lib in main_widget.installed_libraries_provider.installed_libraries)
        if (lib.vapi_path != null) {
          box_package.append (lib.library, lib.library);
          if (!rbtn_package.sensitive) {
            box_package.set_active_id (lib.library);
            rbtn_package.sensitive = true;
          }
        }
    }
    public bool chose_package () {
      return rbtn_package.active;
    }
    public string get_selected_package() {
      return box_package.get_active_text();
    }
    public string get_selected_vapi() {
      return projectfolder.get_relative_path (vapi_chooser.get_file());
    }
    [GtkChild]
    public RadioButton rbtn_package;
    [GtkChild]
    public RadioButton rbtn_vapi;
    [GtkChild]
    public ComboBoxText box_package;
    [GtkChild]
    public FileChooserWidget vapi_chooser;
  }
  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Target.glade")]
  private class TargetTemplate : Box {
    [GtkChild]
    public Viewport vp_sources;
    [GtkChild]
    public Viewport vp_gettext;
    [GtkChild]
    public ListBox gladeui_list;
    [GtkChild]
    public ListBox deps_list;
    [GtkChild]
    public ListBox defs_list;
    [GtkChild]
    public ListBox data_list;
    [GtkChild]
    public ListBox gresources_list;
    [GtkChild]
    public ToolButton btn_add_dep;
    [GtkChild]
    public ToolButton btn_remove_dep;
    [GtkChild]
    public ToolButton btn_edit_dep;
    [GtkChild]
    public ToolButton btn_add_def;
    [GtkChild]
    public ToolButton btn_remove_def;
    [GtkChild]
    public ToolButton btn_edit_def;
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
      cmb_relation.append (Project.ConditionRelation.EXISTS.toString(), "exists");
      cmb_relation.append (Project.ConditionRelation.GREATER.toString(), ">");
      cmb_relation.append (Project.ConditionRelation.GREATER_EQUAL.toString(), ">=");
      cmb_relation.append (Project.ConditionRelation.EQUAL.toString(), "==");
      cmb_relation.append (Project.ConditionRelation.LESSER_EQUAL.toString(), "<=");
      cmb_relation.append (Project.ConditionRelation.LESSER.toString(), "<");
      cmb_relation.set_active_id (condition.relation.toString());
      cmb_relation.changed.connect (()=>{
        condition.relation = Project.ConditionRelation.fromString (cmb_relation.get_active_id());
        ent_version.visible = condition.relation != Project.ConditionRelation.EXISTS;
      });
      ent_version.visible = condition.relation != Project.ConditionRelation.EXISTS;

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

      lbl_title.label = dep.library;

      if (dep.type == Project.DependencyType.PACKAGE)
        img_type.set_from_icon_name (_("_Execute"), IconSize.LARGE_TOOLBAR);
      else
        img_type.set_from_icon_name (_("_File"), IconSize.LARGE_TOOLBAR);

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
        add_dep_dialog();
      });
      btn_remove.clicked.connect (()=>{
        var selected_row = list_dependencies.get_selected_row();
        if (selected_row != null)
          meta_dep.dependencies.remove (selected_row.get_data<Project.Dependency>("dep"));
        update_list ();
      });

      btn_up.clicked.connect (()=>{
        var selected_row = list_dependencies.get_selected_row();
        if (selected_row == null)
          return;
        var dep = selected_row.get_data<Project.Dependency>("dep");
        var index = meta_dep.dependencies.index_of (dep);
        if (index == 0)
          return;
        meta_dep.dependencies.remove (dep);
        meta_dep.dependencies.insert (index - 1, dep);
        update_list ();
      });
      btn_down.clicked.connect (()=>{
        var selected_row = list_dependencies.get_selected_row();
        if (selected_row == null)
          return;
        var dep = selected_row.get_data<Project.Dependency>("dep");
        var index = meta_dep.dependencies.index_of (dep);
        if (index == meta_dep.dependencies.size - 1)
          return;
        meta_dep.dependencies.remove (dep);
        meta_dep.dependencies.insert (index + 1, dep);
        update_list ();
      });

      update_list ();
    }
    public bool add_dep_dialog() {
      var dlg_template = new NewDependencyDialogTemplate(main_widget);
      var new_dep_dialog = new Dialog.with_buttons(_("New dependency"), main_widget.window, DialogFlags.MODAL, _("OK"), ResponseType.OK, _("Cancel"), ResponseType.CANCEL);
      new_dep_dialog.get_content_area().add (dlg_template);
      var ret = new_dep_dialog.run();
      if (ret == ResponseType.OK) {
        var new_dep = new Project.Dependency();
        if (dlg_template.chose_package()) {
          new_dep.type = Project.DependencyType.PACKAGE;
          new_dep.library = dlg_template.get_selected_package();
          var new_cond = new Project.Condition();
          new_cond.relation = Project.ConditionRelation.EXISTS;
          new_cond.library = new_dep.library;
          new_dep.conditions.add (new_cond);
        } else {
          new_dep.type = Project.DependencyType.VAPI;
          new_dep.library = dlg_template.get_selected_vapi();
        }
        meta_dep.dependencies.add (new_dep);
        update_list ();
      }
      new_dep_dialog.destroy();
      return ret == ResponseType.OK;
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
      title = _("Target");

      // Fill buildsystem combo and keep it in sync
      foreach (var i in Builder.EnumBuildsystem.to_array())
        template.combo_buildsystem.append (i.toString(), i.toString());
      template.combo_buildsystem.set_active_id (member.buildsystem.toString());

      template.combo_buildsystem.changed.connect (()=>{
        member.buildsystem = Builder.EnumBuildsystem.fromString(template.combo_buildsystem.get_active_id());
        update_settings_ui();
      });

      // Keep gresources list in sync
      member.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberGResource)
          update_gresources_list();
      });
      member.project.member_removed.connect ((member)=>{
        if (member is Project.ProjectMemberGResource)
          update_gresources_list();
      });
      member.project.member_data_changed.connect((sender, mb)=>{
        if (member is Project.ProjectMemberGResource)
          update_gresources_list();
      });

      // Keep data list in sync
      member.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberData)
          update_data_list();
      });
      member.project.member_removed.connect ((member)=>{
        if (member is Project.ProjectMemberData)
          update_data_list();
      });
      member.project.member_data_changed.connect((sender, mb)=>{
        if (member is Project.ProjectMemberData)
          update_data_list();
      });

      // Keep gladeui list in sync
      member.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberGladeUi)
          update_gladeui_list();
      });
      member.project.member_removed.connect ((member)=>{
        if (member is Project.ProjectMemberGladeUi)
          update_gladeui_list();
      });
      member.project.member_data_changed.connect((sender, mb)=>{
        if (member is Project.ProjectMemberGladeUi)
          update_gladeui_list();
      });

      // Keep binary name entry in sync
      template.ent_binary_name.text = member.binary_name;
      template.ent_binary_name.changed.connect (()=>{
        member.binary_name = template.ent_binary_name.text;
        member.project.member_data_changed (this, member);
      });
      
      widget = template;
      
      // Initial list update
      init_sources_list();
      update_gresources_list();
      update_data_list();
      update_gladeui_list();
      init_gettext_list();
      setup_dependencies_list();
      setup_defines_list();
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
        template.notebook_settings.prepend_page (settings_widget, new Label (_("Settings")));

    }

    // GResources list
    // ===============
    
    private inline void update_gresources_list() {
      foreach (Gtk.Widget widget in template.gresources_list.get_children())
        template.gresources_list.remove (widget);

      var my_member = member as Project.ProjectMemberTarget;
      
      foreach (Project.ProjectMember m in my_member.project.members) {
        if (!(m is Project.ProjectMemberGResource))
          continue;
        
        var row = new Gtk.ListBoxRow();
        var check = new Gtk.CheckButton();
        check.active = m.id in my_member.included_gresources;
        check.label = (m as Project.ProjectMemberGResource).name;
        check.toggled.connect(()=>{
          if (check.active)
            my_member.included_gresources.add (m.id);
          else
            my_member.included_gresources.remove (m.id);
          main_widget.project.member_data_changed (this, my_member);
        });
        
        row.add (check);
        template.gresources_list.add (row);
      }
      template.gresources_list.show_all();
    }

    // Data list
    // ===============
    
    private inline void update_data_list() {
      foreach (Gtk.Widget widget in template.data_list.get_children())
        template.data_list.remove (widget);

      var my_member = member as Project.ProjectMemberTarget;
      
      foreach (Project.ProjectMember m in my_member.project.members) {
        if (!(m is Project.ProjectMemberData))
          continue;
        
        var row = new Gtk.ListBoxRow();
        var check = new Gtk.CheckButton();
        check.active = m.id in my_member.included_data;
        check.label = (m as Project.ProjectMemberData).name;
        check.toggled.connect(()=>{
          if (check.active)
            my_member.included_data.add (m.id);
          else
            my_member.included_data.remove (m.id);
          main_widget.project.member_data_changed (this, my_member);
        });
        
        row.add (check);
        template.data_list.add (row);
      }
      template.data_list.show_all();
    }

    // Sources list
    // ============
    
    private inline void init_sources_list() {
      var treebox = new FileTreeBox (true);
      var my_member = member as Project.ProjectMemberTarget;
      foreach (Project.ProjectMember m in my_member.project.members) {
        if (!(m is Project.ProjectMemberValaSource))
          continue;
        var path = (m as Project.ProjectMemberValaSource).file.get_rel();
        treebox.add_file (path, m, m.id in my_member.included_sources);
      }
      treebox.file_checked.connect ((filename, data, checked)=>{
        var member = data as Project.ProjectMemberValaSource;
        if (checked)
          my_member.included_sources.add (member.id);
        else
          my_member.included_sources.remove (member.id);
        main_widget.project.member_data_changed (this, my_member);
      });
      template.vp_sources.add (treebox.update());
      template.vp_sources.show_all();
      // Keep in sync
      member.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberValaSource) {
          var path = (member as Project.ProjectMemberValaSource).file.get_rel();
          treebox.add_file (path, member, member.id in my_member.included_sources);
        }
      });
      member.project.member_removed.connect ((member)=>{
        if (member is Project.ProjectMemberValaSource) {
          var path = (member as Project.ProjectMemberValaSource).file.get_rel();
          treebox.remove_file (treebox.get_entry(path));
        }
      });
    }

    // Gettext list
    // ============

    private inline void init_gettext_list() {
      var treebox = new FileTreeBox (true);
      var my_member = member as Project.ProjectMemberTarget;
      foreach (Project.ProjectMember m in my_member.project.members) {
        if (!(m is Project.ProjectMemberGettext))
          continue;
        var path = (m as Project.ProjectMemberGettext).potfile.get_rel();
        treebox.add_file (path, m, m.id in my_member.included_gettexts);
      }
      treebox.file_checked.connect ((filename, data, checked)=>{
        var member = data as Project.ProjectMemberGettext;
        if (checked)
          my_member.included_gettexts.add (member.id);
        else
          my_member.included_gettexts.remove (member.id);
        main_widget.project.member_data_changed (this, my_member);
      });
      template.vp_gettext.add (treebox.update());
      template.vp_gettext.show_all();
      // Keep in sync
      member.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberGettext) {
          var path = (member as Project.ProjectMemberGettext).potfile.get_rel();
          treebox.add_file (path, member, member.id in my_member.included_gettexts);
        }
      });
      member.project.member_removed.connect ((member)=>{
        if (member is Project.ProjectMemberGettext) {
          var path = (member as Project.ProjectMemberGettext).potfile.get_rel();
          treebox.remove_file (treebox.get_entry(path));
        }
      });
    }

    // Gladeui list
    // ============

    private inline void update_gladeui_list() {
      foreach (Gtk.Widget widget in template.gladeui_list.get_children())
        template.gladeui_list.remove (widget);

      var my_member = member as Project.ProjectMemberTarget;

      foreach (Project.ProjectMember m in my_member.project.members) {
        if (!(m is Project.ProjectMemberGladeUi))
          continue;

        var row = new Gtk.ListBoxRow();
        var check = new Gtk.CheckButton();
        check.active = m.id in my_member.included_gladeuis;
        check.label = (m as Project.ProjectMemberGladeUi).file.get_rel();
        check.toggled.connect(()=>{
          if (check.active)
            my_member.included_gladeuis.add (m.id);
          else
            my_member.included_gladeuis.remove (m.id);
          main_widget.project.member_data_changed (this, my_member);
        });

        row.add (check);
        template.gladeui_list.add (row);
      }
      template.gladeui_list.show_all();
    }

    // Defines list
    // =================

    private inline void setup_defines_list() {

      template.btn_add_def.clicked.connect (() => {
        var my_member = member as Project.ProjectMemberTarget;
        var new_def = new Project.Define();
        new_def.define = "NEW_DEFINE";
        if (edit_define (new_def, true))
          my_member.defines.add (new_def);
        update_defines_list ();
      });

      template.btn_remove_def.clicked.connect (() => {
        if (template.defs_list.get_selected_row() == null)
          return;
        var my_member = member as Project.ProjectMemberTarget;
        var def = template.defs_list.get_selected_row().get_data<Project.Define>("define");
        my_member.defines.remove (def);
        update_defines_list ();
      });

      template.btn_edit_def.clicked.connect (() => {
        if (template.defs_list.get_selected_row() == null)
          return;

        var def = template.defs_list.get_selected_row().get_data<Project.Define>("define");
        edit_define (def, false);
      });

      //template.defs_list.row_selected.connect(dependencies_list_row_selected);
      update_defines_list();
    }

    private bool edit_define (Project.Define def, bool newly_created) {
      main_widget.installed_libraries_provider.update();

      var editor = new DefineEditorTemplate(main_widget, def);

      /*if (newly_created)
        if (!editor.add_dep_dialog())
          return false;*/

      var edit_dialog = new Dialog.with_buttons("", main_widget.window, DialogFlags.MODAL, _("OK"), ResponseType.OK);
      edit_dialog.get_content_area().add (editor);
      var ret = edit_dialog.run();
      edit_dialog.destroy();
      
      update_defines_list ();
      return true;
    }

    private inline void update_defines_list() {
      foreach (Gtk.Widget widget in template.defs_list.get_children())
        template.defs_list.remove (widget);

      var my_member = member as Project.ProjectMemberTarget;

      foreach (var def in my_member.defines) {
        var row = new Gtk.ListBoxRow();
        row.set_data<Project.Define> ("define", def);
        row.add (new Gtk.Label(def.define));
        template.defs_list.add (row);
      }
      template.defs_list.show_all();
    }


    // Dependencies list
    // =================

    private inline void setup_dependencies_list() {

      template.btn_add_dep.clicked.connect (() => {
        var my_member = member as Project.ProjectMemberTarget;
        var new_dep = new Project.MetaDependency();
        new_dep.name = "New dependency";
        if (edit_meta_dependency (new_dep, true))
          my_member.metadependencies.add (new_dep);
        update_dependencies_list ();
      });

      template.btn_remove_dep.clicked.connect (() => {
        if (template.deps_list.get_selected_row() == null)
          return;
        var my_member = member as Project.ProjectMemberTarget;
        var dep = template.deps_list.get_selected_row().get_data<Project.MetaDependency>("metadependency");
        my_member.metadependencies.remove (dep);
        update_dependencies_list ();
      });

      template.btn_edit_dep.clicked.connect (() => {
        if (template.deps_list.get_selected_row() == null)
          return;

        var dep = template.deps_list.get_selected_row().get_data<Project.MetaDependency>("metadependency");
        edit_meta_dependency (dep, false);
      });

      template.deps_list.row_selected.connect(dependencies_list_row_selected);
      update_dependencies_list();
    }

    // Returns whether inital editing of a new dependency was successful. For not newly created ones, always returns true.
    private bool edit_meta_dependency (Project.MetaDependency dep, bool newly_created) {
      main_widget.installed_libraries_provider.update();

      var editor = new MetaDependencyEditorTemplate(main_widget, dep);

      if (newly_created)
        if (!editor.add_dep_dialog())
          return false;

      var edit_dialog = new Dialog.with_buttons("", main_widget.window, DialogFlags.MODAL, _("OK"), ResponseType.OK);
      edit_dialog.get_content_area().add (editor);
      var ret = edit_dialog.run();
      edit_dialog.destroy();
      
      update_dependencies_list ();
      return true;
    }

    private void dependencies_list_row_selected (Gtk.ListBoxRow? row) {
      template.btn_remove_dep.sensitive = row != null;
      template.btn_edit_dep.sensitive = row != null;
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

    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {

    }
    internal override void destroy_internal() {

    }

  }

}
