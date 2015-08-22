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
    Builder.Builder hooked_builder = null;
    private void hook_save_on_compile() {
      if (hooked_builder != null)
        hooked_builder.disconnect (hook);
      var builder = main_widget.main_toolbar.selected_target.builder;
      hook = builder.state_changed.connect (()=>{
        if (builder.state == Builder.BuilderState.COMPILING)
          write (main_widget.main_toolbar.selected_target);
      });
      hooked_builder = builder;
    }

    // Write the config.vapi
    private void write (Project.ProjectMemberTarget target) {
      DirUtils.create_with_parents ("buildsystems/" + target.binary_name, 509);
      Builder.Helper.write_config_vapi (target, "buildsystems/" + target.binary_name + "/config.vapi");
    }

    public override void destroy() {
      // Write when closing in case some changes were not saved yet
      foreach (var member in main_widget.project.members)
        if (member is Project.ProjectMemberTarget)
          write (member as Project.ProjectMemberTarget);
    }

 }

}
