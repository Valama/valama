namespace Units {

  [DBus (name = "org.valama.codecontextd")]
  public interface CodeContextDaemon : Object {
    public abstract void initialize (string[] defines, string[] vapi_directories, string[] libraries, string[] source_files) throws IOError;

    public abstract string[] completion (string filename, int line, int col, string statement) throws IOError;

    public abstract string[] completion_simple (string filename, int line, int col, string[] fragments) throws IOError;

    public abstract string[] get_errors_serialized() throws IOError;

    public abstract void quitd() throws IOError;
  }

  public class CodeContextProvider : Unit {


    public CodeContextDaemon daemon = null;
    private Pid? daemon_pid = null;

    public Vala.CodeContext context = new Vala.CodeContext();
    //public Vala.Symbol root = null;
    public Report report = new Report();

    public Gee.ArrayList<CompilerError> compiler_errors = new Gee.ArrayList<CompilerError>();

    public signal void pre_context_update();
    public signal void context_updated();
    public signal void report_updated();
    
    public override void init() {

      main_widget.main_toolbar.selected_target_changed.connect(queue_update);
      main_widget.project.member_data_changed.connect((sender, member)=>{
        if (member == current_target) {
          stdout.printf (_("target changed -> update context\n"));
          queue_update();
        }
      });

      update_code_context();
    }

    public override void destroy() {
      if (daemon != null) {
        try {
          daemon.quitd();
        } catch {}
      }
    }

    private Project.ProjectMemberTarget current_target;

    bool update_queued = false;
    bool timeout_active = false;
    public void queue_update () {
      update_queued = true;
      if (!timeout_active)
        update_code_context();
    }

    private void update_code_context() {
      timeout_active = true;
      update_queued = false;

      pre_context_update();
      new Thread<int> ("Context updater", update_code_context_work);
    }

    public Vala.SourceFile? get_sourcefile_by_name (string filename) {
      foreach (var file in context.get_source_files()) {
        if (file.filename == filename)
          return file;
      }
      return null;
    }

    private int daemon_id_counter = 0;
    private int update_code_context_work() {
      stdout.printf (_("===========updating context\n"));
      current_target = main_widget.main_toolbar.selected_target;
      if (current_target == null) {
        timeout_active = false;
        return -1;
      }

      /*if (daemon_pid != null) {
        Process.close_pid (daemon_pid);
      }*/

      daemon_id_counter++;
      string daemon_id = ((int)Posix.getpid()).to_string() + "-" + daemon_id_counter.to_string();

      string[] spawn_args = {Config.DATA_DIR + "/bin/valama-codecontextd", daemon_id};
		  string[] spawn_env = Environ.get ();

		  Process.spawn_async ("/", spawn_args, spawn_env,
                           SpawnFlags.SEARCH_PATH,// | SpawnFlags.DO_NOT_REAP_CHILD,
                           null,
                           out daemon_pid);

      CodeContextDaemon new_daemon = null;
      while (new_daemon == null) {
        try {
          new_daemon = Bus.get_proxy_sync (BusType.SESSION, "org.valama.codecontextd" + daemon_id,
                                                  "/org/valama/codecontextd");
        } catch {
          new_daemon = null;
          GLib.Thread.usleep (10 * 1000);
        }
      }

      // Add defines

      string[] daemon_defines = new string[0];

      foreach (var define in current_target.defines) {
        if (main_widget.installed_libraries_provider.check_define (define)) {
          daemon_defines += define.define;
        }
      }

      // Add packages

      string[] daemon_vapi_dirs = new string[0];
      string[] daemon_pkgs = new string[0];

      foreach (var meta_dep in current_target.metadependencies) {
        var dep = main_widget.installed_libraries_provider.check_meta_dependency (meta_dep);
        if (dep != null) {
          if (dep.type == Project.DependencyType.PACKAGE) {
            daemon_pkgs += dep.library;
          } else if (dep.type == Project.DependencyType.VAPI){
            var vapi_file = File.new_for_path (dep.library);
            var custom_vapi_dir = vapi_file.get_parent().get_path();

            daemon_vapi_dirs += custom_vapi_dir;
            daemon_pkgs += vapi_file.get_basename().replace(".vapi", "");
          }
        }
      }

      // Add source files
      string[] daemon_sources = new string[0];

      foreach (string source_id in current_target.included_sources) {
        var source = main_widget.project.getMemberFromId (source_id) as Project.ProjectMemberValaSource;

        daemon_sources += source.file.get_abs();
      }

      var config_vapi_file = new Project.FileRef.from_rel (main_widget.project, "buildsystems/" + current_target.binary_name + "/config.vapi");
      daemon_sources += config_vapi_file.get_abs();

      try {
        new_daemon.initialize (daemon_defines, daemon_vapi_dirs, daemon_pkgs, daemon_sources);
      } catch {}


      // Deserialize received compiler errors
      var compiler_errors_internal = new Gee.ArrayList<CompilerError>();

      try {
        foreach (var error_serialized in new_daemon.get_errors_serialized()) {
          compiler_errors_internal.add (new CompilerError.deserialize (error_serialized));
        }
      } catch {}
      compiler_errors = compiler_errors_internal;
      GLib.Idle.add (()=>{
        report_updated();
        return false;
      });

      // Make new daemon instance public and quit old one
      CodeContextDaemon old_daemon = daemon;
      daemon = new_daemon;

      if (old_daemon != null) {
        try {
          old_daemon.quitd();
        } catch {}
      }


      GLib.Timeout.add (5000, ()=> {
        timeout_active = false;
        if (update_queued)
          update_code_context();
        return false;
      });
      return 0;
    }

  }

}
