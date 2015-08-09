using Gtk;

namespace Builder {

  public class Valama : Builder {
  
    public override Gtk.Widget? init_ui() {
      return null;
    }
    public override void set_defaults() {
    }
    public override void load (Xml.Node* node) {
    }
    public override void save (Xml.TextWriter writer) {
    }
    public override bool can_export () {
      return false;
    }
    public override void export (Ui.MainWidget main_widget) {
    
    }
    public override void build(Ui.MainWidget main_widget) {

      state = BuilderState.COMPILING;

      var build_dir = "build/" + target.binary_name + "/valama/";
      
      // Create build directory if not existing yet
      DirUtils.create_with_parents (build_dir, 509); // = 775 octal

      var cmd_build = new StringBuilder();
      cmd_build.append ("""/bin/sh -c " """);

      // Write gresource files and compile them
      foreach (string id in target.included_gresources) {
        var gresource = target.project.getMemberFromId (id) as Project.ProjectMemberGResource;
        //var res_path = build_dir + "gresources/gresource_" + id + ".xml";
        var res_path = ".gresource_" + id + ".xml";

        Helper.write_gresource_xml (gresource, res_path);

        cmd_build.append ("glib-compile-resources '" + res_path + "' --generate-source && ");
      }

      // Compiler call
      cmd_build.append ("valac ");
      cmd_build.append ("--target-glib=2.38 ");
      cmd_build.append ("--thread -X -lm ");
      
      string binary_name = target.binary_name;
      if (target.library) {
		cmd_build.append ("-H " + build_dir + target.binary_name + ".h ");
		cmd_build.append ("--vapi " + build_dir + target.binary_name + ".vapi ");
		cmd_build.append ("--gir " + build_dir + target.binary_name + ".gir ");
		cmd_build.append ("--library " + target.binary_name + " -X -fPIC -X -shared ");
		binary_name = "lib" + binary_name + ".so";
	  }
	 
	  cmd_build.append ("-o '" + build_dir + binary_name + "' ");
	    

      // Copy data files, write basedir config vapi
      Helper.write_config_vapi (target, build_dir + "config.vapi");

      foreach (string id in target.included_data) {
        var data = target.project.getMemberFromId (id) as Project.ProjectMemberData;
        cmd_build.append ("-X -D" + data.basedir + """='\"""" + build_dir + "data/" + data.basedir + """/\"' """);

        foreach (var target in data.targets) {
          var target_file = File.new_for_path (build_dir + "data/" + data.basedir + "/" + target.target);
          var orig_file = File.new_for_path (target.file);
          DirUtils.create_with_parents (target_file.get_parent().get_path(), 509); // = 775 octal
          Helper.copy_recursive (orig_file, target_file, FileCopyFlags.OVERWRITE, null);
        }
      }

      // TODO: Get rid of this once translation support is there
      cmd_build.append ("""-X -DGETTEXT_PACKAGE='\"valamang\"' """);

      cmd_build.append ("'" + build_dir + "config.vapi' ");

      // Add defines
      foreach (var define in target.defines) {
        if (main_widget.installed_libraries_provider.check_define (define))
          cmd_build.append ("--define=" + define.define + " ");
      }

      // Add dependencies
      foreach (var meta_dep in target.metadependencies) {
        var dep = main_widget.installed_libraries_provider.check_meta_dependency (meta_dep);
        if (dep != null) {
          if (dep.type == Project.DependencyType.PACKAGE)
            cmd_build.append ("--pkg " + dep.library + " ");
          else if (dep.type == Project.DependencyType.VAPI){
            var vapi_file = File.new_for_path (dep.library);
            var custom_vapi_dir = vapi_file.get_parent().get_path();

            cmd_build.append ("--vapidir='" + custom_vapi_dir + "' ");
            cmd_build.append ("--pkg " + vapi_file.get_basename().replace(".vapi", "") + " ");
          }
        } else {
          // TODO: Report missing deps
        }
      }

      // Add resources
      foreach (string id in target.included_gresources) {
        var gresource = target.project.getMemberFromId (id) as Project.ProjectMemberGResource;
        //var res_path = build_dir + "gresources/gresource_" + id + ".xml";
        var res_path = ".gresource_" + id + ".xml";

        cmd_build.append ("--gresources '" + res_path + "' '" + res_path.replace(".xml",".c") + "' ");
      }

      // Add sources
      foreach (string id in target.included_sources) {
        var source = target.project.getMemberFromId (id) as Project.ProjectMemberValaSource;
        cmd_build.append ("'" + source.file.get_rel() + "' ");
      }

      cmd_build.append (""" """");
      // "
      Pid child_pid = main_widget.console_view.spawn_process (cmd_build.str);

      ulong process_exited_handler = 0;
      process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
        foreach (string id in target.included_gresources) {
          var gresource = target.project.getMemberFromId (id) as Project.ProjectMemberGResource;
          var res_path = ".gresource_" + id + ".xml";
          FileUtils.remove (res_path);
          FileUtils.remove (res_path.replace (".xml", ".c"));
        }
        state = BuilderState.COMPILED_OK;
        main_widget.console_view.disconnect (process_exited_handler);
      });
    }

    Pid run_pid;
    public override void run(Ui.MainWidget main_widget) {
      var build_dir = "build/" + target.binary_name + "/valama/";
      run_pid = main_widget.console_view.spawn_process (build_dir + target.binary_name);

      state = BuilderState.RUNNING;

      ulong process_exited_handler = 0;
      process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
        state = BuilderState.COMPILED_OK;
        main_widget.console_view.disconnect (process_exited_handler);
      });
    }

    public override void abort_run() {
      Posix.kill (run_pid, 15);
      Process.close_pid (run_pid);
    }

    public override void clean() {
    
    }

  }
}
