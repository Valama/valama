namespace Ui {

  public class EditorValaSource : Editor {
  
    public Gtk.SourceView sourceview = new Gtk.SourceView ();
  
    private Project.ProjectMemberValaSource my_member = null;
  
    private bool unsaved_changes = false;

    public EditorValaSource(Project.ProjectMemberValaSource member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      my_member = member as Project.ProjectMemberValaSource;
      title = member.file.get_rel();

      sourceview.buffer = member.buffer;

      sourceview.show_line_numbers = true;
      sourceview.insert_spaces_instead_of_tabs = true;
      sourceview.override_font (Pango.FontDescription.from_string ("Monospace 10"));
      sourceview.auto_indent = true;
      sourceview.indent_width = 2;

      var srcw_sourceview = new Gtk.ScrolledWindow (null, null);
      srcw_sourceview.add (sourceview);

      widget = srcw_sourceview;
      widget.show_all();

      main_widget.main_toolbar.selected_target_changed.connect(hook_save_on_compile);
      hook_save_on_compile();

      // When content is changed, invalidate all targets depending on this file
      sourceview.buffer.changed.connect (()=>{
        unsaved_changes = true;

        foreach (var pmember in my_member.project.members) {
          if (pmember is Project.ProjectMemberTarget) {
            var target = pmember as Project.ProjectMemberTarget;
            if (target.included_sources.contains (my_member.id))
              target.builder.state = Builder.BuilderState.NOT_COMPILED;
          }
        }
      });
    }

    // Before compiling, save file (if it is part of the selected target)
    ulong hook = 0;
    Builder.Builder hooked_builder = null;
    private void hook_save_on_compile() {
      if (hooked_builder != null) // track selected target
        hooked_builder.disconnect (hook);
      var builder = main_widget.main_toolbar.selected_target.builder;
      hook = builder.state_changed.connect (()=>{
        if (unsaved_changes)
          if (builder.state == Builder.BuilderState.COMPILING)
            if (main_widget.main_toolbar.selected_target.included_sources.contains (my_member.id))
              save_file (my_member.file.get_abs(), my_member.buffer.text);
      });
      hooked_builder = builder;
    }

    private Gtk.TextIter iter_from_location (Vala.SourceLocation location) {
      Gtk.TextIter titer;
      my_member.buffer.get_iter_at_line (out titer, location.line -1);
      titer.forward_chars (location.column - 1);
      return titer;
    }

    public void jump_to_sourceref (Vala.SourceReference sourceref) {
      var iter_begin = iter_from_location (sourceref.begin);
      var iter_end = iter_from_location (sourceref.end);
      iter_end.forward_char();
      my_member.buffer.select_range (iter_begin, iter_end);
      GLib.Idle.add(()=>{
          sourceview.grab_focus();
          sourceview.scroll_to_iter (iter_begin, 0.42, true, 1.0, 1.0);
          return false;
      });
    }

    public void jump_to_position (int line, int col) {
      Gtk.TextIter titer;
      my_member.buffer.get_iter_at_line_offset (out titer, line, col);
      my_member.buffer.select_range (titer, titer);
      GLib.Idle.add(()=>{
          sourceview.grab_focus();
          sourceview.scroll_to_iter (titer, 0.42, true, 1.0, 1.0);
          return false;
      });
    }
    
    private bool save_file (string filename, string text) {

      unsaved_changes = false;

      var file = File.new_for_path (filename);

      /* TODO: First parameter can be used to check if file has changed.
       *       The second parameter can enable/disable backup file. */
      try {
          var fos = file.replace (null, false, FileCreateFlags.REPLACE_DESTINATION);
          var dos = new DataOutputStream (fos);
          dos.put_string (text);
          dos.flush();
          dos.close();
          //msg (_("File saved: %s\n"), file.get_path());
          return true;
      } catch (GLib.IOError e) {
          //errmsg (_("Could not update file: %s\n"), e.message);
      } catch (GLib.Error e) {
          //errmsg (_("Could not open file writable: %s\n"), e.message);
      }
      return false;
    }
    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {
    }
    internal override void destroy_internal() {
      save_file (my_member.file.get_abs(), my_member.buffer.text);
    }
  }

}
