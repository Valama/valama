namespace Units {

  public class ErrorMarker : Unit {
    
    public override void init() {
      // Register tags on existing and following source members
      foreach (var member in main_widget.project.members) {
        if (member is Project.ProjectMemberValaSource) {
          var source_member = member as Project.ProjectMemberValaSource;
          register_tags (source_member.buffer);
        }
      }
      main_widget.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberValaSource) {
          var source_member = member as Project.ProjectMemberValaSource;
          register_tags (source_member.buffer);
        }
      });

      // Update with every context update
      main_widget.code_context_provider.context_updated.connect (update);
      update();
    }

    private void update() {
      // First, clear all error tags from all buffers
      foreach (var member in main_widget.project.members) {
        if (member is Project.ProjectMemberValaSource) {
          var source_member = member as Project.ProjectMemberValaSource;
          clear_tag (source_member.buffer, "EM_err");
          clear_tag (source_member.buffer, "EM_warn");
          //clear_tag (source_member.buffer, "EM_warn");
        }
      }
      
      // Then, add new error tags
      var report = main_widget.code_context_provider.report;
      foreach (var error in report.errlist) {
        if (error.source == null)
          return;
        string myfilename = error.source.file.get_relative_filename();
        var member = get_source_member_by_file (myfilename);
        
        var iter_start = iter_from_location (member.buffer, error.source.begin);
        var iter_end = iter_from_location (member.buffer, error.source.end);
        iter_end.forward_char();
        
        member.buffer.apply_tag_by_name ("EM_err", iter_start, iter_end);
        
      }

    }

    private Gtk.TextIter iter_from_location (Gtk.SourceBuffer buffer, Vala.SourceLocation location) {
      Gtk.TextIter titer;
      buffer.get_iter_at_line (out titer, location.line -1);
      titer.forward_chars (location.column - 1);
      return titer;
    }

    // Registers all needed tags on buffer
    private void register_tags (Gtk.SourceBuffer buffer) {
      Gtk.TextTag tag = buffer.create_tag ("EM_err", null);
      tag.underline = Pango.Underline.ERROR;
      tag = buffer.create_tag ("EM_warn", null);
      tag.background_rgba = Gdk.RGBA() { red = 1.0, green = 1.0, blue = 0.8, alpha = 1.0 };
    }

    // Removes a certain tag from a buffer
    private void clear_tag (Gtk.SourceBuffer buffer, string tag) {
      Gtk.TextIter first_iter, end_iter;
      buffer.get_start_iter (out first_iter);
      buffer.get_end_iter (out end_iter);

      buffer.remove_tag_by_name (tag, first_iter, end_iter);
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
