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
      var toolbar = new Gtk.HeaderBar();
      toolbar.title = "Valama";
      toolbar.subtitle = "Next generation of an amazing IDE";
      toolbar.show_close_button = true;
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
      
      toolbar.pack_start (target_selector);
      
      btnBuild = new Gtk.MenuToolButton (null, "Build");
      btnBuild.icon_name = "system-run";
      btnBuild.set_menu (build_build_menu());
      toolbar.pack_start (btnBuild);
      btnBuild.set_tooltip_text (_("Build project"));
      btnBuild.clicked.connect (() => {
        selected_target.builder.build(main_widget);
      });

      btnRun = new Gtk.ToolButton (null, "Run");
      toolbar.pack_start (btnRun);
      btnRun.set_tooltip_text (_("Run project"));
      btnRun.clicked.connect (() => {
        var state = selected_target.builder.state;
        if (state == Builder.BuilderState.RUNNING)
          selected_target.builder.abort_run();
        else if (state == Builder.BuilderState.COMPILED_OK)
          selected_target.builder.run(main_widget);
        else {
          // If not compiled, first compile, then run
          ulong hook_id = 0;
          var target = selected_target; // Keep target in case it is changed in between
          hook_id = selected_target.builder.state_changed.connect (()=>{
            var state_new = target.builder.state;
            if (state_new == Builder.BuilderState.COMPILED_OK) {
              target.builder.run(main_widget);
            }
            else if (state_new != Builder.BuilderState.COMPILED_ERROR)
              return;
            target.builder.disconnect (hook_id);
          });
          target.builder.build(main_widget);
        }
      });

      update_target_selector();
      update_build_button();

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
    ulong state_change_id = 0;
    ulong builder_change_id = 0;
    Project.ProjectMemberTarget old_target = null;
    private void update_build_button() {
      if (selected_target == null) {
        btnBuild.sensitive = false;
        return;
      }
      // Track builders and states
      if (old_target != null) {
        old_target.builder.disconnect (state_change_id);
        old_target.disconnect (builder_change_id);
      }
      builder_change_id = selected_target.builder_changed.connect(()=>{
        update_build_button();
      });
      state_change_id = selected_target.builder.state_changed.connect (()=>{
        update_build_button();
      });

      var state = selected_target.builder.state;
      btnBuild.sensitive = !(state == Builder.BuilderState.RUNNING || state == Builder.BuilderState.COMPILING);
      btnRun.sensitive = state != Builder.BuilderState.COMPILING;
      if (state == Builder.BuilderState.RUNNING)
        btnRun.icon_name = "media-playback-stop";
      else
        btnRun.icon_name = "media-playback-start";

      item_build_export.sensitive = selected_target.builder.can_export();

      old_target = selected_target;
    }

    private Gtk.MenuItem item_build_export;
    private Gtk.Menu build_build_menu () {
        var menu_build = new Gtk.Menu();

        item_build_export = new Gtk.MenuItem.with_label (_("Export"));
        menu_build.append (item_build_export);
        item_build_export.activate.connect (() => {
          selected_target.builder.export(main_widget);
        });

        //var item_build_clean = new Gtk.ImageMenuItem.with_mnemonic (_("_Clean"));
        /*var image_build_clean = new Image();
        image_build_clean.icon_name = "edit-clear";
        item_build_clean.image = image_build_clean;*/
        /*menu_build.append (item_build_clean);
        item_build_clean.activate.connect (() => {
            //project_builder.clean_project();
        });*/
        menu_build.show_all();
        return menu_build;
    }
    
    public override void destroy() {
    
    }
  }

}
