namespace Ui {

  public abstract class Viewer : Object {
  
    public string title;
    public EnumViewer type;

    public MainWidget main_widget;
    public Gtk.Widget widget;
    
    internal abstract void destroy_internal();
    
    public signal void destroyed();
    public void destroy() {
      destroy_internal();
      destroyed();
    }

    public virtual void save (Xml.TextWriter writer) {
      writer.start_element ("viewer");
      writer.write_attribute ("type", type.toString());
      save_internal (writer);
      writer.end_element();
    }
    public abstract void save_internal (Xml.TextWriter writer);
    public abstract void load_internal (Xml.TextWriter writer);
  
  }

}
