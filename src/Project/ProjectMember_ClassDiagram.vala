namespace Project {

  public class ProjectMemberClassDiagram : ProjectMember {

    public override EnumProjectMember get_project_member_type() {
      return EnumProjectMember.CLASS_DIAGRAM;
    }

    public abstract class Display : Object {
      public abstract void destroy ();
      public abstract void save (Xml.TextWriter writer);
      public abstract void update (Vala.Symbol root, Clutter.Actor stage);
    }
  
    public class ClassDisplay : Display {
      private const string font = "Monospace 10";
      public ClassDisplay (string class_name) {
        this.class_name = class_name;
      }
      public ClassDisplay.from_xml (Xml.Node* node) {
        for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
          if (prop->name == "name")
            class_name = prop->children->content;
          else if (prop->name == "x")
            x = int.parse(prop->children->content);
          else if (prop->name == "y")
            y = int.parse(prop->children->content);
        }
      }
      public int x = 0;
      public int y = 0;
      public string class_name = null;
      public override void save (Xml.TextWriter writer) {
        writer.start_element ("class");
        writer.write_attribute ("name", class_name);
        writer.write_attribute ("x", x.to_string());
        writer.write_attribute ("y", y.to_string());
        writer.end_element();
      }
      Vala.Class symbol = null;
      public override void destroy () {
        box.destroy();
      }
      Clutter.Actor box = null;
      public override void update (Vala.Symbol root, Clutter.Actor stage) {
        var finder = new CodeContextHelpers.SymbolByName();
        var found_symbol = finder.get_symbol_by_full_name (root, class_name);
        if (found_symbol == null)
          symbol = null;
        else if (!(found_symbol is Vala.Class))
          symbol = null;
        else
          symbol = found_symbol as Vala.Class;

        if (box != null)
          box.destroy();
        box = new Clutter.Actor();
        box.reactive = true;
        box.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        box.set_easing_duration (250);

        var drag_action = new Clutter.DragAction();
        drag_action.drag_begin.connect(()=>{
          box.opacity = 150;
          box.set_easing_duration (0);
        });
        drag_action.drag_end.connect ((actor, event_x, event_y)=>{
          box.set_easing_duration (250);
          x = (int)grid_align(box.x);
          y = (int)grid_align(box.y);
          box.x = x;
          box.y = y;
          box.opacity = 255;
        });

        box.add_action (drag_action);
        box.background_color = Clutter.Color.get_static (Clutter.StaticColor.SKY_BLUE_LIGHT);
        box.x = x;
        //box.width = 190;
        box.y = y;

        //var layout = new Clutter.GridLayout();
        var layout = new Clutter.FlowLayout(Clutter.FlowOrientation.VERTICAL);
        box.set_layout_manager (layout);

        //layout.orientation = Clutter.Orientation.VERTICAL;
        //layout.row_spacing = 3;
        
        if (symbol == null) {
          var text_smbname = new Clutter.Text.full (font, class_name, 
                    Clutter.Color() {red = 220, green = 220, blue = 220, alpha = 255});
          //layout.attach (text_smbname, 0, 0, 1, 1);
          box.add_child (text_smbname);

          var text_notfound = new Clutter.Text.full (font, "Not found", 
                    Clutter.Color() {red = 100, green = 100, blue = 100, alpha = 255});
          //layout.attach (text_smbname, 0, 0, 1, 1);
          box.add_child (text_notfound);
        } else {

          var text_smbname = new Clutter.Text.full (font, symbol.name, 
                            Clutter.Color() {red = 220, green = 220, blue = 220, alpha = 255});
          //layout.attach (text_smbname, 0, 0, 1, 1);
          box.add_child (text_smbname);

          int cnt = 1;
          foreach (var method in symbol.get_methods()) {
            if (method.access != Vala.SymbolAccessibility.PUBLIC)
              continue;
            var text = new Clutter.Text.full (font, method.name, 
                              Clutter.Color() {red = 200, green = 0, blue = 0, alpha = 255});
            //layout.attach (text, 0, cnt, 1, 1);
            box.add_child (text);
            cnt++;
          }
          foreach (var field in symbol.get_fields()) {
            if (field.access != Vala.SymbolAccessibility.PUBLIC)
              continue;
            var text = new Clutter.Text.full (font, field.name, 
                              Clutter.Color() {red = 0, green = 50, blue = 200, alpha = 255});
            //layout.attach (text, 0, cnt, 1, 1);
            box.add_child (text);
            cnt++;
          }
        }
        stage.add (box);

      }
      inline float grid_align (float val) {
        if (val < 0)
          val = 0;
        return Math.floorf((val + 50.0f) / 100.0f) * 100 + 5;
      }
    }
  
    public Gee.ArrayList <Display> displays = new Gee.ArrayList <Display>();
    
    public string name = null;
    
    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "name")
          name = prop->children->content;
      }
      for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;
        if (iter->name == "class") {
          var new_class_display = new ClassDisplay.from_xml(iter);
          displays.add (new_class_display);
        }
      }
    }
    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("name", name);
      foreach (var display in displays) {
        display.save (writer);
      }
    }
    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorClassDiagram(this, main_widget);
    }
    public override string getTitle() {
      return "Diagram";
    }
  }

}
