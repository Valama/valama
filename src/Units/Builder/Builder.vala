namespace Builder {
  public abstract class Builder {
  
    public string build_dir;
    public Project.ProjectMemberTarget target;
  
    public abstract void init_ui();
  
    public Gtk.Widget widget;
  
    public abstract void build();
    public abstract void run();
    public abstract void clean();

  }
}
