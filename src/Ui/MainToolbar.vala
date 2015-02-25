namespace Ui {

  public class MainToolbar : Element {
    
    private Gtk.ComboBoxText target_selector;

    public signal void selected_target_changed ();
    public Project.ProjectMemberTarget selected_target = null;

    private Gtk.MenuToolButton btnBuild;
    private Gtk.ToolButton btnRun;

    public override void init() {
      
      main_widget.project.member_added.connect((member)=>{
        if (!(member is Project.ProjectMemberTarget))
          return;
        update_target_selector();
      });
      main_widget.project.member_removed.connect((member)=>{
        if (!(member is Project.ProjectMemberTarget))
          return;
        if (selected_target == member)
          selected_target = null;
        update_target_selector();
      });
      main_widget.project.member_data_changed.connect ((sender, member)=>{
        if (!(member is Project.ProjectMemberTarget))
          return;
        update_target_selector();
      });

      // Build toolbar
      var toolbar = new Gtk.Toolbar();
      var toolbar_scon = toolbar.get_style_context();
      toolbar_scon.add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
      target_selector = new Gtk.ComboBoxText();
      target_selector.changed.connect(()=>{
        var selected_id = target_selector.get_active_id();
        if (selected_id == null)
          return;
        var new_target = main_widget.project.getMemberFromId(selected_id)
                           as Project.ProjectMemberTarget;
        bool changed = new_target.id != selected_target.id;
        selected_target = new_target;
        if (changed) {
          selected_target_changed ();
          update_build_button();
        }
      });
      var ti = new Gtk.ToolItem();
      ti.add (target_selector);
      toolbar.add (ti);
      
      btnBuild = new Gtk.MenuToolButton (null, "Build");
      btnBuild.icon_name = "system-run";
      btnBuild.set_menu (build_build_menu());
      toolbar.add (btnBuild);
      btnBuild.set_tooltip_text ("Save current file and build project");
      btnBuild.clicked.connect (() => {
        selected_target.builder.build();
      });

      btnRun = new Gtk.ToolButton (null, "Run");
      btnRun.icon_name = "system-run";
      toolbar.add (btnRun);
      btnRun.set_tooltip_text ("Run project");
      btnRun.clicked.connect (() => {
        selected_target.builder.run();
      });

      update_target_selector();
      
      toolbar.show_all();
      widget = toolbar;
    }

    private void update_target_selector() {
      target_selector.remove_all();
      foreach (var member in main_widget.project.members) {
        if (!(member is Project.ProjectMemberTarget))
          continue;
        if (selected_target == null) {
          selected_target = member as Project.ProjectMemberTarget;
          selected_target_changed ();
          update_build_button();
        }
        target_selector.append (member.id, member.getTitle());
      }
      target_selector.set_active_id (selected_target.id);
    }

    // On target change
    ulong state_change_id = -1;
    ulong builder_change_id = -1;
    Project.ProjectMemberTarget old_target = null;
    private void update_build_button() {
      if (selected_target == null) {
        btnBuild.sensitive = false;
        return;
      }
      if (state_change_id != -1) {
        old_target.builder.disconnect (state_change_id);
        old_target.disconnect (builder_change_id);
      }
      builder_change_id = selected_target.builder_changed.connect(()=>{
        update_build_button();
      });
      state_change_id = selected_target.builder.state_changed.connect (()=>{
        var building = selected_target.builder.state == Builder.BuilderState.COMPILING;
        var running = selected_target.builder.state == Builder.BuilderState.RUNNING;
        btnBuild.sensitive = running || building;
        btnRun.sensitive = running || building;
      });
      old_target = selected_target;
    }

    private Gtk.Menu build_build_menu () {
        var menu_build = new Gtk.Menu();

        var item_build_rebuild = new Gtk.ImageMenuItem.with_label ("Rebuild");
        menu_build.append (item_build_rebuild);
        item_build_rebuild.activate.connect (() => {
            //project_builder.build_project (true);
        });

        var item_build_clean = new Gtk.ImageMenuItem.with_mnemonic ("_Clean");
        /*var image_build_clean = new Image();
        image_build_clean.icon_name = "edit-clear";
        item_build_clean.image = image_build_clean;*/
        menu_build.append (item_build_clean);
        item_build_clean.activate.connect (() => {
            //project_builder.clean_project();
        });
        menu_build.show_all();
        return menu_build;
    }
    
    public override void destroy() {
    
    }
  }

}
