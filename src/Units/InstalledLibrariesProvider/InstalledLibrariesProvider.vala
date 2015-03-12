
/*
  Unit:         InstalledLibrariesProvider
  Purpose:      Provide list of installed libraries
  Unit deps:    none
*/

namespace Units {

  public class InstalledLibrariesProvider : Unit {
    
    public struct InstalledLibrary {
      public string library;
      public string description;
      public string? vapi_path;
    }

    public override void init() {
    }
    public override void destroy() {
    }

    private bool check_condition (Project.Condition condition) {
      string relation_string = "";
      if (condition.relation == Project.ConditionRelation.GREATER)
        relation_string = ">";
      else if (condition.relation == Project.ConditionRelation.GREATER_EQUAL)
        relation_string = ">=";
      else if (condition.relation == Project.ConditionRelation.LESSER_EQUAL)
        relation_string = "<=";
      else if (condition.relation == Project.ConditionRelation.LESSER)
        relation_string = "<";
      else if (condition.relation == Project.ConditionRelation.EQUAL)
        relation_string = "=";

      if (condition.relation != Project.ConditionRelation.EXISTS)
        relation_string += " " + condition.version;

      int pkg_exit;
      var pkg_cmd = "pkg-config --exists '" + condition.library + " " + relation_string + "'";
      Process.spawn_command_line_sync (pkg_cmd, null, null, out pkg_exit);
      return pkg_exit == 0;
    }

    public bool check_define(Project.Define define) {
      foreach (var condition in define.conditions)
        if (!check_condition(condition))
          return false;
      return true;
    }

    public Project.Dependency? check_meta_dependency (Project.MetaDependency meta_dep) {
      foreach (var dep in meta_dep.dependencies) {

        bool conds_fulfilled = true;
        foreach (var condition in dep.conditions)
          if (!check_condition(condition)) {
            conds_fulfilled = false;
            break;
          }

        if (conds_fulfilled)
          return dep;
      }
      return null;
    }

    public Gee.TreeSet<InstalledLibrary?> installed_libraries = new Gee.TreeSet<InstalledLibrary?>();
    public void update() {
      assert(main_widget.code_context_provider.context != null);

      installed_libraries = new Gee.TreeSet<InstalledLibrary?>((a,b) => {
        if (a.library > b.library)
          return 1;
        if (a.library < b.library)
          return -1;
        return 0;
      });
    
      // Get pkg-config libraries
      string pkgconfig_out;
      Process.spawn_command_line_sync ("pkg-config --list-all", out pkgconfig_out, null, null);
      var lines = pkgconfig_out.split ("\n");

      // Split it into lib names and descriptions
      foreach (var line in lines) {
        if (line == "")
          continue;

        var linesplit = line.split (" ", 2);

        var lib = InstalledLibrary();
        lib.library = linesplit[0];
        lib.description = linesplit[1].chug();
        lib.vapi_path = main_widget.code_context_provider.context.get_vapi_path (lib.library);

        installed_libraries.add (lib);
      }
    }
    

 }

}
