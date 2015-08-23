using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/SearchView.glade")]
  private class SearchViewTemplate : Box {
    [GtkChild]
    public Revealer rev_search;
    [GtkChild]
    public SearchEntry ent_search;
    [GtkChild]
    public ListBox list_results;
  }

  public class SearchView : Element {

    private SearchViewTemplate template = new SearchViewTemplate();

    public void show (bool visible) {
      template.rev_search.reveal_child = visible;
      if (visible)
        template.ent_search.grab_focus();
    }

    public override void init() {
      template.show_all();
      widget = template;
      template.ent_search.changed.connect(()=>{
        search();
      });
      template.list_results.row_selected.connect ((row)=>{
        if (row == null)
          return;
        var result = row.get_data<Search.SearchResult>("search_result");
        result.activate();
      });
    }

    private void search() {
      foreach (Gtk.Widget widget in template.list_results.get_children())
        template.list_results.remove (widget);

      var search_text = template.ent_search.text;
      foreach (var member in main_widget.project.members) {
        if (member.search_provider == null)
          continue;
        var results = member.search_provider.search (main_widget, search_text);
        foreach (var result in results) {
          var row = new Gtk.ListBoxRow ();
          row.add (result.widget);
          row.set_data<Search.SearchResult>("search_result", result);
          template.list_results.add (row);
        }
      }
      template.list_results.show_all();
    }

    public override void destroy() {
      
    }
  }

}
