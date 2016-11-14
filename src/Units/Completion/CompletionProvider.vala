namespace Units {

  public class CompletionProvider : Unit {
    
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
      var comp_provider = new GuanakoCompletion(main_widget, member);
      comp_provider.srcview = editor.sourceview;
      comp_provider.srcbuffer = member.buffer;
      editor.sourceview.completion.add_provider (comp_provider);
      main_widget.code_context_provider.pre_context_update.connect (()=>{
        if (editor.has_unsaved_changes())
          editor.save_file();
      });
    }

    private void update() {
      
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
