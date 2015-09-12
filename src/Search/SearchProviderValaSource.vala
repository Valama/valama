namespace Search {

  // Search result for a matching source file name
  public class SearchResultValaSourceFilename : SearchResult {
    public SearchResultValaSourceFilename (Ui.MainWidget main_widget, Project.ProjectMemberValaSource member) {
      this.main_widget = main_widget;
      this.member = member;

      widget = new Gtk.Label (member.file.get_rel());
    }

    public override void activate () {
      // Show file's editor
      main_widget.editor_viewer.openMember (member);
    }

    Ui.MainWidget main_widget = null;
    weak Project.ProjectMemberValaSource member;
  }

  // Search result for a source file content match
  public class SearchResultValaSourceContent : SearchResult {
    public SearchResultValaSourceContent (Ui.MainWidget main_widget, Project.ProjectMemberValaSource member, Gtk.TextIter start, Gtk.TextIter end) {
      this.main_widget = main_widget;
      this.member = member;

      // Save position as marks (iters are not persistent!)
      buffer = start.get_buffer();
      buffer.add_mark (mark_start, start);
      buffer.add_mark (mark_end, end);

      // Show some text around the actual match in the result
      if (!end.ends_line())
        end.forward_to_line_end();
      end.forward_to_line_end();
      end.forward_to_line_end();
      if (!start.starts_line())
        start.backward_line();
      start.backward_line();

      var text = buffer.get_text (start, end, false);
      widget = new Gtk.Label (text);
    }

    public override void activate () {
      // Jump to matched text
      main_widget.editor_viewer.openMember (member);
      var editor = member.editor as Ui.EditorValaSource;
      Gtk.TextIter iter_start, iter_end;
      buffer.get_iter_at_mark (out iter_start, mark_start);
      buffer.get_iter_at_mark (out iter_end, mark_end);
      editor.jump_to_iter (iter_start, iter_end);
    }

    Gtk.TextBuffer buffer = null;
    Ui.MainWidget main_widget = null;
    Gtk.TextMark mark_start = new Gtk.TextMark(null);
    Gtk.TextMark mark_end = new Gtk.TextMark(null);
    weak Project.ProjectMemberValaSource member;
  }

  public class SearchProviderValaSource : SearchProvider {
    weak Project.ProjectMemberValaSource member;

    public SearchProviderValaSource (Project.ProjectMemberValaSource member) {
      this.member = member;

      // Add highlight color for content matches
      var tag = member.buffer.create_tag ("search", null);
      tag.background_rgba = Gdk.RGBA() { red = 1.0, green = 1.0, blue = 0, alpha = 0.8 };
    }
    public override void reset() {
      // Remove all highlights for content matches
      Gtk.TextIter iter_start, iter_end;
      member.buffer.get_start_iter(out iter_start);
      member.buffer.get_end_iter(out iter_end);
      member.buffer.remove_tag_by_name ("search", iter_start, iter_end);
    }
    public override Gee.LinkedList<SearchResult> search(Ui.MainWidget main_widget, string text) {

      Gee.LinkedList<SearchResult> results = new Gee.LinkedList<SearchResult>();

      // Search file name
      if (member.file.get_rel().contains (text))
        results.add (new SearchResultValaSourceFilename (main_widget, member));

      // Search file content
      Gtk.TextIter iter;
      member.buffer.get_start_iter(out iter);
      Gtk.TextIter? match_start = null;
      Gtk.TextIter? match_end = null;

      while (iter.forward_search (text, Gtk.TextSearchFlags.CASE_INSENSITIVE, out match_start, out match_end, null)) {
        iter = match_end;
        // Highlight result
        member.buffer.apply_tag_by_name ("search", match_start, match_end);

        results.add (new SearchResultValaSourceContent (main_widget, member, match_start, match_end));
      }

      return results;
    }
  }
}