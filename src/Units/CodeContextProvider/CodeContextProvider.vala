namespace Units {

  public class CodeContextProvider : Unit {
    public Vala.CodeContext? context = null;
    //public Vala.Symbol root = null;
    public Report report = new Report();
    
    public signal void context_updated();
    
    public override void init() {
      main_widget.main_toolbar.selected_target_changed.connect(queue_update);
      main_widget.project.member_data_changed.connect((sender, member)=>{
        if (member == current_target) {
          stdout.printf ("target changed -> update context\n");
          queue_update();
        }
      });
      
      update_code_context();
    }
    public override void destroy() {
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

      new Thread<int> ("Context updater", update_code_context_work);
    }

    public Vala.SourceFile? get_sourcefile_by_name (string filename) {
      foreach (var file in context.get_source_files()) {
        if (file.filename == filename)
          return file;
      }
      return null;
    }

    private int update_code_context_work() {
      stdout.printf ("===========updating context\n");
      current_target = main_widget.main_toolbar.selected_target;
      if (current_target == null) {
        timeout_active = false;
        return -1;
      }

      Vala.CodeContext context_internal = new Vala.CodeContext();

      var report_internal = new Report();
      context_internal.report = report_internal;

      Vala.CodeContext.push (context_internal);
      
      context_internal.profile = Vala.Profile.GOBJECT;
      context_internal.add_define ("GOBJECT");

      context_internal.target_glib_major = 2;
      context_internal.target_glib_minor = 18;


      foreach (var define in current_target.defines) {
        if (main_widget.installed_libraries_provider.check_define (define))
          context_internal.add_define (define.define);
      }

      foreach (var meta_dep in current_target.metadependencies) {
        var dep = main_widget.installed_libraries_provider.check_meta_dependency (meta_dep);
        if (dep != null) {
          if (dep.type == Project.DependencyType.PACKAGE)
            context_internal.add_external_package (dep.library);
          //else if (dep.type == Project.DependencyType.VAPI)
          //TODO: Handle VAPIs
        }
      }
      string pkgs[2] = {"glib-2.0", "gobject-2.0"};
      foreach (string pkg in pkgs) {
        context_internal.add_external_package (pkg);
      }
      
      foreach (string source_id in current_target.included_sources) {
        var source = main_widget.project.getMemberFromId (source_id) as Project.ProjectMemberValaSource;

			  var source_file = new Vala.SourceFile (context_internal, Vala.SourceFileType.SOURCE, source.filename, source.buffer.text, false);
			  source_file.relative_filename = source.filename;

			  var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib", null));
			  source_file.add_using_directive (ns_ref);
			  context_internal.root.add_using_directive (ns_ref);

        context_internal.add_source_file (source_file);
      }


      var parser = new Vala.Parser();
      parser.parse (context_internal);

      context_internal.check ();

      Vala.CodeContext.pop();
      
      context = context_internal;
      report = report_internal;



      GLib.Idle.add (()=>{
        context_updated();
        return false;
      });

      GLib.Timeout.add_seconds (2, ()=> {
        timeout_active = false;
        if (update_queued)
          update_code_context();
        return false;
      });
      return 0;
    }
  }

}
