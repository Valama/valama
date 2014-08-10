namespace Ui {

  public class EditorViewer : Element {
  
    Gee.ArrayList<Editor> editors = new Gee.ArrayList<Editor>();
  
    public Gtk.Widget widget;
    private Gtk.Notebook notebook;

    public override void init() {
      
      notebook = new Gtk.Notebook();
      notebook.show();
      widget = notebook;
      widget.hexpand = true;
      widget.vexpand = true;
    }
  
    public void openMember (Project.ProjectMember member) {
      // Check if member is shown already
      foreach (var editor in editors)
        if (editor.member == member) {
          // Focus existing editor
          notebook.set_current_page (notebook.page_num (editor.widget));
          return;
        }

      // Create new editor
      var editor = member.createEditor();
      editors.add (editor);
      
      // Create title for new tab
      var title_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
      title_box.add (new Gtk.Label(editor.title));
      
      var button_close = new Gtk.Button.from_stock(Gtk.Stock.CLOSE);
      button_close.label = "x";
      button_close.always_show_image = true;
      button_close.set_relief(Gtk.ReliefStyle.NONE);
      button_close.set_focus_on_click(false);
      
      main_widget.project.member_removed.connect ((removed_member)=>{
        if (removed_member == member)
          remove_editor (editor);
      });
      button_close.clicked.connect(()=>{
        remove_editor (editor);
      });
      title_box.add (button_close);
      title_box.show_all();
      
      // Add page and focus
      notebook.append_page (editor.widget, title_box);
      notebook.set_tab_reorderable (editor.widget, true);
      notebook.set_current_page (notebook.page_num (editor.widget));
    }
    private void remove_editor (Editor editor) {
      editor.dispose();
      notebook.remove_page (notebook.page_num (editor.widget));
      editors.remove (editor);    
    }
    public override void dispose() {
      
    }
  }

}
