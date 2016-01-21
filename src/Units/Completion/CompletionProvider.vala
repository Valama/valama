namespace Units {

  public class CompletionProvider : Unit {
    
    private Guanako.Project guanako_project = null;
    
    public override void init() {
      // Register provider on existing and following source members
      main_widget.project.member_editor_created.connect((member, new_editor)=>{
        if (member is Project.ProjectMemberValaSource) {
          var source_member = member as Project.ProjectMemberValaSource;
          var editor = new_editor as Ui.EditorValaSource;
          if (editor != null)
            completify_editor (source_member, editor);
        }
      });
      foreach (var member in main_widget.project.members) {
        if (member is Project.ProjectMemberValaSource) {
          var source_member = member as Project.ProjectMemberValaSource;
          var editor = member.editor as Ui.EditorValaSource;
          if (editor != null)
            completify_editor (source_member, editor);
        }
      }

      // Update with every context update
      main_widget.code_context_provider.context_updated.connect (update);
      update();

    }

    private void completify_editor (Project.ProjectMemberValaSource member, Ui.EditorValaSource editor) {
	  //create guanako project & context only if provider's context is not null.
	  if (guanako_project == null && main_widget.code_context_provider.context != null)
        guanako_project = new Guanako.Project(main_widget.code_context_provider.context, Config.DATA_DIR + "/share/valama/guanako/syntax");
      var sourcefile = main_widget.code_context_provider.get_sourcefile_by_name (member.file.get_abs());
      var comp_provider = new Guanako.GuanakoCompletion();
      comp_provider.srcview = editor.sourceview;
      comp_provider.srcbuffer = member.buffer;
      comp_provider.guanako_project = guanako_project;
      comp_provider.source_file = sourcefile;
      editor.sourceview.completion.add_provider (comp_provider);
    }

    private void update() {
      
    }

    private Gtk.TextIter iter_from_location (Gtk.SourceBuffer buffer, Vala.SourceLocation location) {
      Gtk.TextIter titer;
      buffer.get_iter_at_line (out titer, location.line -1);
      titer.forward_chars (location.column - 1);
      return titer;
    }

    private Project.ProjectMemberValaSource get_source_member_by_file (string filename) {
      // Find project member
      Project.ProjectMemberValaSource source_member = null;
      foreach (var member in main_widget.project.members)
        if (member is Project.ProjectMemberValaSource) {
          source_member = member as Project.ProjectMemberValaSource;
          if (source_member.file.get_rel() == filename)
            break;
        }
      return source_member;
    }
    
    public override void destroy() {
    }

 }

}
