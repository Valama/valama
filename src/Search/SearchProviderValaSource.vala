namespace Search {

  public class SearchResultValaSource : SearchResult {
    public SearchResultValaSource (Ui.MainWidget main_widget, Project.ProjectMemberValaSource member, Gtk.TextIter start, Gtk.TextIter end) {
      this.main_widget = main_widget;
      this.member = member;

      buffer = start.get_buffer();
      buffer.add_mark (mark_start, start);
      buffer.add_mark (mark_end, end);
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
    }
    public override Gee.LinkedList<SearchResult> search(Ui.MainWidget main_widget, string text) {
      Gee.LinkedList<SearchResult> results = new Gee.LinkedList<SearchResult>();

      Gtk.TextIter iter;
      member.buffer.get_start_iter(out iter);
      Gtk.TextIter? match_start = null;
      Gtk.TextIter? match_end = null;

      while (iter.forward_search (text, Gtk.TextSearchFlags.CASE_INSENSITIVE, out match_start, out match_end, null)) {
        iter = match_end;
        results.add (new SearchResultValaSource (main_widget, member, match_start, match_end));
      }

      return results;
    }
  }
}