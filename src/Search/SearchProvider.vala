namespace Search {

  public abstract class SearchResult : Object {
    public Gtk.Widget widget;
    public abstract void activate();
  }

  public abstract class SearchProvider : Object {
    public abstract void reset();
    public abstract Gee.LinkedList<SearchResult> search(Ui.MainWidget main_widget, string text);
  }
}