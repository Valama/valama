namespace Ui {

  public class EditorViewer : Element {
  
    Gee.ArrayList<Viewer> viewers = new Gee.ArrayList<Editor>();
  
    private Gtk.Notebook notebook;

    public override void init() {
      
      notebook = new Gtk.Notebook();
      notebook.show();
      widget = notebook;
      widget.hexpand = true;
      widget.vexpand = true;

      // Load viewer state file
      Xml.Doc* doc = Xml.Parser.parse_file (GLib.Environment.get_home_dir() + "/.config/valama/" + main_widget.project.id + ".xml");
      if (doc == null)
        return;

      Xml.Node* root = doc->get_root_element ();
      if (root == null)
        return;
      //  throw new ProjectError.FILE("Config file empty");

      // Iterate first level of config file, pass on to viewers / editors
      for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;

        if (iter->name == "editor") {
          string memberid = null;
          for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
            if (prop->name == "memberid")
              memberid = prop->children->content;
          }
          var member = main_widget.project.getMemberFromId(memberid);
          openMember (member);
        } else if (iter->name == "viewer") {
          
          
        }
      }

      // Restore active tab
      for (Xml.Attr* prop = root->properties; prop != null; prop = prop->next) {
        if (prop->name == "activetab")
          notebook.set_current_page(int.parse(prop->children->content));
      }
      
      delete doc;
    }
  
    public void openMember (Project.ProjectMember member) {
      // Check if member is shown already
      foreach (var viewer in viewers) {
        if (!(viewer is Editor))
          continue;
        var editor = viewer as Editor;
        if (editor.member == member) {
          // Focus existing editor
          notebook.set_current_page (notebook.page_num (editor.widget));
          return;
        }
      }

      // Create new editor
      var editor = member.createEditor(main_widget);
      viewers.add (editor);
      
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
          remove_viewer (editor);
      });
      button_close.clicked.connect(()=>{
        remove_viewer (editor);
      });
      title_box.add (button_close);
      title_box.show_all();
      
      // Add page and focus
      editor.widget.set_data<Viewer> ("viewer", editor);
      notebook.append_page (editor.widget, title_box);
      notebook.set_tab_reorderable (editor.widget, true);
      notebook.set_current_page (notebook.page_num (editor.widget));
    }
    private void remove_viewer (Viewer viewer) {
      viewers.remove (viewer);    
      viewer.destroy();
      notebook.remove_page (notebook.page_num (viewer.widget));
    }
    public override void destroy() {
      var writer = new Xml.TextWriter.filename (GLib.Environment.get_home_dir() + "/.config/valama/" + main_widget.project.id + ".xml");
      writer.set_indent (true);
      writer.set_indent_string ("\t");

      writer.start_document ();
      writer.start_element ("project");
      
      // Write selected tab index
      writer.write_attribute ("activetab", notebook.get_current_page().to_string());
      
      // Save viewers in current order
      for (int page = 0; page < notebook.get_n_pages(); page++) {
        var widget = notebook.get_nth_page(page);
        var viewer = widget.get_data<Viewer> ("viewer");
        viewer.save (writer);
      }
      
      writer.end_element();
      writer.end_document();

      writer.flush();
      
      foreach (var viewer in viewers)
        viewer.destroy();
    }
  }
}
