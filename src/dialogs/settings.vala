using Gtk;

public SourceStyleScheme source_style;

void load_source_style() {
    var settings = new GLib.Settings ("org.valama");
    var s = new SourceStyleSchemeManager ();
    source_style = s.get_scheme (settings.get_string ("current-color-scheme"));
    if(source_style == null) {
        stderr.printf(" \x1b[31mCouldn't load source style\n\x1b[0m");
    }
}

public class IDESettingsWindow : Window {
    private string[] color_scheme_list;
    private string current_color_scheme;
    public signal void color_scheme_changed();
    
    public IDESettingsWindow () {
        this.title = "IDE Settings";
        this.window_position = WindowPosition.CENTER;
        this.set_default_size (400, 400);
        var settings = new GLib.Settings ("org.valama");
        current_color_scheme = settings.get_string ("current-color-scheme");
        var notebook = new Notebook ();
        this.add (notebook);
        var manager = new SourceStyleSchemeManager ();
        color_scheme_list = manager.get_scheme_ids ();
        var items = new ListBox ();
        for(var i = 0; i < color_scheme_list.length; i++) {
            items.insert(new Label(color_scheme_list[i]), i);
            if(color_scheme_list[i] == current_color_scheme) {
                items.select_row (items.get_row_at_index (i));
            }
        }
        items.row_selected.connect(select_item);
        var scrolled = new ScrolledWindow (null, null);
        scrolled.add (items);
        notebook.append_page (scrolled, new Label ("Color scheme"));
    }
    
    private void select_item(ListBoxRow? row) {
        var item = (Label)row.get_child ();
        var settings = new GLib.Settings ("org.valama");
        settings.set_string ("current-color-scheme", item.label);
        load_source_style ();
        color_scheme_changed();
    }
}
