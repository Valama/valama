namespace Ui {

  public class EditorClassDiagram : Editor {
  
  
    private Gtk.ListBox typeslist = null;
    private GtkClutter.Embed embed;

    public EditorClassDiagram(Project.ProjectMemberClassDiagram member, MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      title = "Info";
      
      var txt_name = new Gtk.Entry();
      txt_name.text = member.name;
      txt_name.changed.connect (()=>{
        member.name = txt_name.text;
        member.project.member_data_changed (this, member);
      });
      

      embed = new GtkClutter.Embed ();
      //drawing_area.hexpand = true;
      //drawing_area.vexpand = true;

      typeslist = new Gtk.ListBox();
      var scrw_typeslist = new Gtk.ScrolledWindow (null, null);
      scrw_typeslist.add (typeslist);
      scrw_typeslist.set_size_request (250, 0);
 
      var btn_edit = new Gtk.ToggleButton.with_label("Edit");
      //btn_edit.icon_name = "list-add-symbolic";
      btn_edit.toggled.connect (()=>{
        scrw_typeslist.visible = btn_edit.active;
        if (scrw_typeslist.visible)
          update_typeslist();
      });
     
      var grid = new Gtk.Grid();
      grid.attach (descriptionLabel("Diagram name"), 0, 0, 1, 1);
      grid.attach (txt_name, 1, 0, 1, 1);
      grid.attach (btn_edit, 2, 0, 1, 1);
      grid.attach (embed, 0, 1, 3, 1);
      grid.attach (scrw_typeslist, 3, 1, 1, 1);

      
      main_widget.code_context_provider.context_updated.connect(()=>{
        update_diagram();
        if (scrw_typeslist.visible)
          update_typeslist();
      });

      grid.show_all();
      scrw_typeslist.visible = false;
      widget = grid;
    }
    
    private void update_diagram() {
      var my_member = member as Project.ProjectMemberClassDiagram;
      foreach (var display in my_member.displays) {
        display.update (main_widget.code_context_provider.root, embed.get_stage());
      }
    }
    
    private void update_typeslist() {
      foreach (Gtk.Widget widget in typeslist.get_children())
        typeslist.remove (widget);

      var my_member = member as Project.ProjectMemberClassDiagram;

      var typeiterator = new CodeContextHelpers.TraverseTypes();
      typeiterator.traverse (main_widget.code_context_provider.root, (symbol)=>{
        var row = new Gtk.ListBoxRow();
        var check = new Gtk.CheckButton();
        
        //check.active = m.id in my_member.included_sources;
        check.label = symbol.get_full_name();
        foreach (var display in my_member.displays) {
          if (!(display is Project.ProjectMemberClassDiagram.ClassDisplay))
            continue;
          var classdisplay = display as Project.ProjectMemberClassDiagram.ClassDisplay;
          if (classdisplay.class_name == symbol.get_full_name()) {
            check.active = true;
            break;
          }
        }
        check.toggled.connect(()=>{
          if (check.active) {
            var new_display = new Project.ProjectMemberClassDiagram.ClassDisplay(symbol.get_full_name());
            my_member.displays.add (new_display);
            update_diagram();
          } else {
            foreach (var display in my_member.displays) {
              if (!(display is Project.ProjectMemberClassDiagram.ClassDisplay))
                continue;
              var classdisplay = display as Project.ProjectMemberClassDiagram.ClassDisplay;
              if (classdisplay.class_name == symbol.get_full_name()) {
                my_member.displays.remove (display);
                display.destroy();
                break;
              }
            }
          }
        });
        row.add (check);
        typeslist.add (row);
      });
      typeslist.show_all();
    }

    public override void save_internal (Xml.TextWriter writer) {

    }
    public override void load_internal (Xml.TextWriter writer) {

    }
    private inline Gtk.Label descriptionLabel (string text) {
      var label = new Gtk.Label (text);
      label.xalign = 1.0f;
      return label;
    }
    internal override void destroy_internal() {
    
    }
  }

}
