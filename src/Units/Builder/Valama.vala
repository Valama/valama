using Gtk;

namespace Builder {

  public class Valama : Builder {
  
    public override Gtk.Widget? init_ui() {
      return null;
    }
    public override void load (Xml.Node* node) {
    }
    public override void save (Xml.TextWriter writer) {
    }
    private ulong process_exited_handler;
    public override void build(Ui.MainWidget main_widget) {

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

        var file = File.new_for_path (res_path);
        if (file.query_exists ())
          file.delete ();

        var dos = new DataOutputStream (file.create (FileCreateFlags.REPLACE_DESTINATION));
        dos.put_string ("""<?xml version="1.0" encoding="UTF-8"?>""" + "\n");
        dos.put_string ("""<gresources>""" + "\n");
        dos.put_string ("""<gresource prefix="/">""" + "\n");
        
        foreach (var res in gresource.resources) {
          dos.put_string ("""<file>""" + res.file.get_rel() + """</file>""" + "\n");
        }

        dos.put_string ("""</gresource>""" + "\n");
        dos.put_string ("""</gresources>""" + "\n");

        cmd_build.append ("glib-compile-resources '" + res_path + "' --generate-source && ");
      }

      // Compiler call
      cmd_build.append ("valac ");
      cmd_build.append ("--target-glib=2.38 ");
      cmd_build.append ("--thread -X -lm ");
      cmd_build.append ("-o '" + build_dir + target.binary_name + "' ");

      // Copy data files, write basedir config vapi
      var vapi = File.new_for_path (build_dir + "config.vapi");
      if (vapi.query_exists ())
        vapi.delete ();
      var dos = new DataOutputStream (vapi.create (FileCreateFlags.REPLACE_DESTINATION));
      dos.put_string ("""[CCode (cprefix = "", lower_case_cprefix = "")]""" + "\n");
      dos.put_string ("namespace Config {\n");

      foreach (string id in target.included_data) {
        var data = target.project.getMemberFromId (id) as Project.ProjectMemberData;
        dos.put_string ("  public const string " + data.basedir + ";\n");
        cmd_build.append ("-X -D" + data.basedir + """='\"""" + build_dir + "data/" + data.basedir + """/\"' """);

        foreach (var target in data.targets) {
          var target_file = File.new_for_path (build_dir + "data/" + data.basedir + "/" + target.target);
          var orig_file = File.new_for_path (target.file);
          DirUtils.create_with_parents (target_file.get_parent().get_path(), 509); // = 775 octal
          copy_recursive (orig_file, target_file, FileCopyFlags.OVERWRITE, null);
        }
      }

      dos.put_string ("}\n");
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

      state = BuilderState.COMPILING;

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

    // Recursive copying
    // From http://stackoverflow.com/questions/16453739/how-do-i-recursively-copy-a-directory-using-vala
    private bool copy_recursive (GLib.File src, GLib.File dest, GLib.FileCopyFlags flags = GLib.FileCopyFlags.NONE, GLib.Cancellable? cancellable = null) throws GLib.Error {
      GLib.FileType src_type = src.query_file_type (GLib.FileQueryInfoFlags.NONE, cancellable);
      if (src_type == GLib.FileType.DIRECTORY ) {
        if (!dest.query_exists())
          dest.make_directory (cancellable);
        src.copy_attributes (dest, flags, cancellable);

        string src_path = src.get_path ();
        string dest_path = dest.get_path ();
        GLib.FileEnumerator enumerator = src.enumerate_children (GLib.FileAttribute.STANDARD_NAME, GLib.FileQueryInfoFlags.NONE, cancellable);
        for ( GLib.FileInfo? info = enumerator.next_file (cancellable) ; info != null ; info = enumerator.next_file (cancellable) ) {
          copy_recursive (
            GLib.File.new_for_path (GLib.Path.build_filename (src_path, info.get_name ())),
            GLib.File.new_for_path (GLib.Path.build_filename (dest_path, info.get_name ())),
            flags,
            cancellable);
        }
      } else if ( src_type == GLib.FileType.REGULAR ) {
        src.copy (dest, flags, cancellable);
      }

      return true;
    }

    Pid run_pid;
    public override void run(Ui.MainWidget main_widget) {
      var build_dir = "build/" + target.binary_name + "/valama/";
      run_pid = main_widget.console_view.spawn_process (build_dir + target.binary_name);

      state = BuilderState.RUNNING;

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
