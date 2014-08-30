namespace Units {

  public class SourceBufferManager : Unit {
    
    public override void init() {
      // Setub buffers on existing and following source members
      foreach (var member in main_widget.project.members) {
        if (member is Project.ProjectMemberValaSource) {
          var source_member = member as Project.ProjectMemberValaSource;
          setup_buffer (source_member.buffer);
        }
      }
      main_widget.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberValaSource) {
          var source_member = member as Project.ProjectMemberValaSource;
          setup_buffer (source_member.buffer);
        }
      });
    }


    // Registers all needed tags on buffer
    private void setup_buffer (Gtk.SourceBuffer buffer) {
      buffer.set_highlight_syntax (true);
      var langman = new Gtk.SourceLanguageManager();
      var lang = langman.get_language ("vala");
      if (lang != null)
        buffer.set_language (lang);

      buffer.highlight_matching_brackets = true;

      buffer.changed.connect (()=>{
        main_widget.code_context_provider.queue_update();
      });
    }
    
    public override void destroy() {
    }

 }

}
