namespace Ui {

  public abstract class Editor : Object {
  
    public string title;
  
    public Gtk.Widget widget;
    
    public Project.ProjectMember member;
    
    public abstract void dispose();
  
  }

}
