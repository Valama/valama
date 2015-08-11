using Gtk;

namespace Builder {

  public class CMake : Builder {
  
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

      var build_dir = "build/" + target.binary_name + "/cmake";
      
      // Create build directory if not existing yet
      DirUtils.create_with_parents (build_dir + "/build", 509); // = 775 octal
      DirUtils.create_with_parents (build_dir + "/gresources", 509);
      DirUtils.create_with_parents (build_dir + "/install", 509);

      var buildsystem_dir = "buildsystems/" + target.binary_name + "/cmake";

      DirUtils.create_with_parents (buildsystem_dir + "/cmake_modules", 509);

      Helper.copy_recursive (File.new_for_path (Config.DATA_DIR + "/Data/CMake"), File.new_for_path (buildsystem_dir + "/cmake_modules"), FileCopyFlags.OVERWRITE, null);

      var file = File.new_for_path ("CMakeLists.txt");
      if (file.query_exists ())
          file.delete ();


      var dos = new DataOutputStream (file.create (FileCreateFlags.REPLACE_DESTINATION));
      dos.put_string ("cmake_minimum_required(VERSION \"2.8.4\")\n");
      dos.put_string ("\n");

      dos.put_string ("list(APPEND CMAKE_MODULE_PATH \"${CMAKE_SOURCE_DIR}/" + buildsystem_dir + "/cmake_modules\")\n");
      dos.put_string ("list(APPEND CMAKE_MODULE_PATH \"${CMAKE_SOURCE_DIR}/" + buildsystem_dir + "/cmake_modules/vala\")\n");
      dos.put_string ("\n");

      dos.put_string ("find_package(PkgConfig)\n");
      dos.put_string ("find_package(Vala)\n");
      dos.put_string ("\n");

      dos.put_string ("set(project_name \"" + target.binary_name + "\")\n");
      dos.put_string ("string(TOLOWER \"${project_name}\" project_name_lower)\n");
      dos.put_string ("\n");

      dos.put_string ("add_definitions(-DGETTEXT_PACKAGE=\"${project_name_lower}\")\n");
      dos.put_string ("\n");

      // Add sources
      dos.put_string ("set(srcfiles\n");
      foreach (string id in target.included_sources) {
        var source = target.project.getMemberFromId (id) as Project.ProjectMemberValaSource;
        dos.put_string ("  \"" + source.file.get_rel() + "\"\n");
      }
      dos.put_string (")\n");
      dos.put_string ("\n");

      // Rebuild dependency structure in cmake
      foreach (var meta_dep in target.metadependencies) {
        dos.put_string ("message (\"-- checking dependency " + meta_dep.name + "\")\n");
        dos.put_string ("set (found FALSE)\n");
        foreach (var dep in meta_dep.dependencies) {
          dos.put_string ("if (NOT found)\n");
          dos.put_string ("  message (\"--  checking option " + dep.library + "\")\n");
          dos.put_string ("  set (cond_found TRUE)\n");
          
          foreach (var condition in dep.conditions) {
            dos.put_string ("  pkg_check_modules (DEP_" + condition.library + " QUIET " + condition.library + ")\n");
            if (condition.relation == Project.ConditionRelation.EXISTS)
              dos.put_string ("  if (NOT DEP_" + condition.library + "_VERSION)\n");
            else if (condition.relation == Project.ConditionRelation.EQUAL)
              dos.put_string ("  if (NOT (DEP_" + condition.library + "_VERSION VERSION_EQUAL \"" + condition.version + "\"))\n");
            else if (condition.relation == Project.ConditionRelation.GREATER)
              dos.put_string ("  if (NOT DEP_" + condition.library + "_VERSION VERSION_GREATER \"" + condition.version + "\"))\n");
            else if (condition.relation == Project.ConditionRelation.LESSER)
              dos.put_string ("  if (NOT DEP_" + condition.library + "_VERSION VERSION_LESS \"" + condition.version + "\"))\n");
            else if (condition.relation == Project.ConditionRelation.GREATER_EQUAL)
              dos.put_string ("  if (DEP_" + condition.library + "_VERSION VERSION_LESS \"" + condition.version + "\")\n");
            else if (condition.relation == Project.ConditionRelation.LESSER_EQUAL)
              dos.put_string ("  if (DEP_" + condition.library + "_VERSION VERSION_GREATER \"" + condition.version + "\")\n");
            dos.put_string ("    set (cond_found FALSE)\n");
            dos.put_string ("  endif ()\n");
          }
          if (dep.type == Project.DependencyType.VAPI) {
            dos.put_string ("  if (cond_found)\n");
            var vapi_file = File.new_for_path (dep.library);
            var custom_vapi_dir = File.new_for_path(target.project.filename).get_parent().get_relative_path (vapi_file.get_parent());
            dos.put_string ("    set (found TRUE)\n");
            dos.put_string ("    list(APPEND vapidirs \"--vapidir=${CMAKE_SOURCE_DIR}/" + custom_vapi_dir + "\")\n");
            dos.put_string ("    list(APPEND required_pkgs \"" + vapi_file.get_basename().replace(".vapi", "") + "\")\n");
            dos.put_string ("  endif ()\n");
          } else if (dep.type == Project.DependencyType.PACKAGE) {
            dos.put_string ("  if (cond_found)\n");
            dos.put_string ("    set (found TRUE)\n");
            if (dep.library == "posix")
              dos.put_string ("    list(APPEND required_pkgs \"" + dep.library + " {nocheck}\")\n");
            else
              dos.put_string ("    list(APPEND required_pkgs \"" + dep.library + "\")\n");
            dos.put_string ("  endif ()\n");
          }
          dos.put_string ("endif ()\n");
        }
        dos.put_string ("if (NOT found)\n");
        dos.put_string ("  message (\"PROBLEM!!\")\n");
        dos.put_string ("endif ()\n");
        dos.put_string ("\n");
      }


      // Add defines
      foreach (var define in target.defines) {
        dos.put_string ("set (cond_found TRUE)\n");
        foreach (var condition in define.conditions) {
          dos.put_string ("pkg_check_modules (DEP_" + condition.library + " QUIET " + condition.library + ")\n");
          if (condition.relation == Project.ConditionRelation.EXISTS)
            dos.put_string ("if (NOT DEP_" + condition.library + "_VERSION)\n");
          else if (condition.relation == Project.ConditionRelation.EQUAL)
            dos.put_string ("if (NOT (DEP_" + condition.library + "_VERSION VERSION_EQUAL \"" + condition.version + "\"))\n");
          else if (condition.relation == Project.ConditionRelation.GREATER)
            dos.put_string ("if (NOT DEP_" + condition.library + "_VERSION VERSION_GREATER \"" + condition.version + "\"))\n");
          else if (condition.relation == Project.ConditionRelation.LESSER)
            dos.put_string ("if (NOT DEP_" + condition.library + "_VERSION VERSION_LESS \"" + condition.version + "\"))\n");
          else if (condition.relation == Project.ConditionRelation.GREATER_EQUAL)
            dos.put_string ("if (DEP_" + condition.library + "_VERSION VERSION_LESS \"" + condition.version + "\")\n");
          else if (condition.relation == Project.ConditionRelation.LESSER_EQUAL)
            dos.put_string ("if (DEP_" + condition.library + "_VERSION VERSION_GREATER \"" + condition.version + "\")\n");
          dos.put_string ("  set (cond_found FALSE)\n");
          dos.put_string ("endif ()\n");
        }
        dos.put_string ("if (cond_found)\n");
        dos.put_string ("  list(APPEND definitions \"" + define.define + "\")\n");
        dos.put_string ("endif ()\n");
        dos.put_string ("\n");
      }


      // Write gresource files
      foreach (string id in target.included_gresources) {
        var gresource = target.project.getMemberFromId (id) as Project.ProjectMemberGResource;
        //var res_path = build_dir + "gresources/gresource_" + id + ".xml";
        var res_path = "gresource_" + id + ".xml";
        var res_out_path = "${CMAKE_BINARY_DIR}/gresource_" + id + ".c";

        dos.put_string ("add_custom_command(\n");
        dos.put_string ("  OUTPUT\n");
        dos.put_string ("    \"" + res_out_path + "\"\n");
        dos.put_string ("  WORKING_DIRECTORY\n");
        dos.put_string ("    ${CMAKE_SOURCE_DIR}\n");
        dos.put_string ("  COMMAND\n");
        dos.put_string ("    glib-compile-resources \"${CMAKE_SOURCE_DIR}/" + res_path + "\" --generate-source --target=\"" + res_out_path + "\"\n");
        dos.put_string ("  DEPENDS\n");
        foreach (var res in gresource.resources) {
          dos.put_string ("   \"" + res.file.get_rel() + "\"\n");
        }
        dos.put_string ("  COMMENT \"Building resource " + gresource.name + "\"\n");
        dos.put_string (")\n");

        Helper.write_gresource_xml (gresource, res_path);
        dos.put_string ("list(APPEND vapidirs --gresources \"${CMAKE_SOURCE_DIR}/" + res_path + "\")\n");
        dos.put_string ("list(APPEND vapifiles \"" + res_out_path + "\")\n");
        dos.put_string ("list(APPEND compiled_resources \"" + res_out_path + "\")\n");

        dos.put_string ("\n");
      }

      // Copy data files, write basedir config vapi
      Helper.write_config_vapi (target, buildsystem_dir + "/config.vapi");
      dos.put_string ("list(APPEND vapifiles \"" + buildsystem_dir + "/config.vapi\")\n");

      foreach (string id in target.included_data) {
        var data = target.project.getMemberFromId (id) as Project.ProjectMemberData;
        //TODO: Generalize
        string target_dir = "${CMAKE_INSTALL_PREFIX}/share/valamang";
        foreach (var data_target in data.targets) {
          string type_string = "FILES";
          if (data_target.is_folder)
            type_string = "DIRECTORY";

          dos.put_string ("install(" + type_string + " \"" + data_target.file + "\" DESTINATION \"" + target_dir + data_target.target + "\")\n");
        }
        dos.put_string ("add_definitions(-D" + data.basedir + "=\"" + target_dir + "\")\n");
        dos.put_string ("\n");
      }

      dos.put_string ("set(default_vala_flags\n");
      dos.put_string ("  \"--thread\"\n");
      dos.put_string ("  \"--target-glib=2.38\"\n");
      dos.put_string ("  \"--enable-experimental\"\n");
      //dos.put_string ("  "--fatal-warnings"\n");
      dos.put_string (")\n");
      dos.put_string ("\n");

      dos.put_string ("include(ValaPkgs)\n");
      dos.put_string ("vala_pkgs(VALA_C\n");
      dos.put_string ("  PACKAGES\n");
      dos.put_string ("    ${required_pkgs}\n");
      dos.put_string ("  DEFINITIONS\n");
      dos.put_string ("    ${definitions}\n");
      dos.put_string ("  SRCFILES\n");
      dos.put_string ("    ${srcfiles}\n");
      dos.put_string ("  VAPIS\n");
      dos.put_string ("    ${vapifiles}\n");
      
      Project.ProjectMemberInfo info = null;
      foreach (var pm in target.project.members) {
        if (pm is Project.ProjectMemberInfo) {
	      info = pm as Project.ProjectMemberInfo;
	      break;
        }
      }

      if (target.library) {
		    dos.put_string ("  LIBRARY\n");
		    dos.put_string ("    \"${project_name_lower}\"\n");
		    dos.put_string ("  GIRFILE\n");
		    string gir_version = "0.1";
        if (info != null)
          gir_version = "%d.%d".printf (info.major, info.minor);
        dos.put_string ("    \"${project_name}-" + gir_version + "\"\n");
      }
      dos.put_string ("  OPTIONS\n");
      dos.put_string ("    ${default_vala_flags}\n");
      dos.put_string ("    ${vapidirs}\n");
      dos.put_string (")\n");
      dos.put_string ("\n");

      if (target.library) {
        dos.put_string ("add_library(\"${project_name_lower}\" SHARED ${VALA_C} ${compiled_resources})\n");
        dos.put_string ("set_target_properties(\"${project_name_lower}\" PROPERTIES\n");
        dos.put_string ("  VERSION \"${${project_name}_VERSION}\"\n");
        dos.put_string ("  SOVERSION %d\n".printf (info == null ? 0 : info.major));
        dos.put_string (")\n");
      }
      else
        dos.put_string ("add_executable(\"${project_name_lower}\" ${VALA_C} ${compiled_resources})\n");
      dos.put_string ("\n");

      dos.put_string ("target_link_libraries(\"${project_name_lower}\"\n");
      dos.put_string ("  ${PROJECT_LDFLAGS}\n");
      dos.put_string ("  -lm\n");
      dos.put_string (")\n");
      dos.put_string ("\n");

      dos.put_string ("add_definitions(\n");
      dos.put_string ("  ${PROJECT_C_FLAGS}\n");
      dos.put_string (")\n");

      // Execute cmake and make
      var project_dir = File.new_for_path (target.project.filename).get_parent().get_path();
      var local_install_dir = project_dir + "/" + build_dir + "/install";
      Pid child_pid = main_widget.console_view.spawn_process (
              "/bin/sh -c \"cd '" + project_dir + "/" + build_dir + "/build' && cmake -DCMAKE_INSTALL_PREFIX:PATH='" + local_install_dir + "' ../../../../ && make && make install\"",
              build_dir + "/build");

      ulong process_exited_handler = 0;
      process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
        /*foreach (string id in target.included_gresources) {
          var gresource = target.project.getMemberFromId (id) as Project.ProjectMemberGResource;
          var res_path = ".gresource_" + id + ".xml";
          FileUtils.remove (res_path);
          FileUtils.remove (res_path.replace (".xml", ".c"));
        }*/
        state = BuilderState.COMPILED_OK;

        main_widget.console_view.disconnect (process_exited_handler);
      });
    }

    Pid run_pid;
    public override void run(Ui.MainWidget main_widget) {
      var build_dir = "build/" + target.binary_name + "/cmake/build/";
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
