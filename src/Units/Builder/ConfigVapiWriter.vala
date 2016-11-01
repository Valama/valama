namespace Units {

  /*
   * Tracks targets and data members, writes the config.vapi's
   */

  public class ConfigVapiWriter : Unit {
    
    public override void init() {
      // Track selected target
      main_widget.main_toolbar.selected_target_changed.connect(hook_save_on_compile);
      hook_save_on_compile();
    }

    // Write when compiling
    ulong hook = 0;
    ulong hook_target = 0;
    Builder.Builder hooked_builder = null;
    Project.ProjectMemberTarget hooked_target = null;
    private void hook_save_on_compile() {
      if (hooked_target != null)
        hooked_target.disconnect (hook_target);
      hooked_target = main_widget.main_toolbar.selected_target;
      hook_target = hooked_target.builder_changed.connect(()=>{
        GLib.Idle.add (()=>{
          hook_save_on_compile();
          return false;
        });
      });

      if (hooked_builder != null)
        hooked_builder.disconnect (hook);
      hooked_builder = main_widget.main_toolbar.selected_target.builder;
      hook = hooked_builder.state_changed.connect (()=>{
        if (hooked_builder.state == Builder.BuilderState.COMPILING)
          write (main_widget.main_toolbar.selected_target);
      });
    }

    // Write the config.vapi
    private void write (Project.ProjectMemberTarget target) {
      var config_vapi_path = new Project.FileRef.from_rel(main_widget.project, "buildsystems/" + target.binary_name + "/config.vapi");
      DirUtils.create_with_parents (config_vapi_path.get_abs(), 509);
      Builder.Helper.write_config_vapi (target, config_vapi_path.get_abs());
    }

    public override void destroy() {
      // Write when closing in case some changes were not saved yet
      foreach (var member in main_widget.project.members)
        if (member is Project.ProjectMemberTarget)
          write (member as Project.ProjectMemberTarget);
    }

 }

}
