namespace Builder {
  public abstract class Builder {
  
    public string build_dir;
    public Project.ProjectMemberTarget target;
  
    public abstract Gtk.Widget? init_ui();
  
    public abstract void build();
    public abstract void run();
    public abstract void clean();
    public abstract void load (Xml.Node* node);
    public abstract void save (Xml.TextWriter writer);
  }
}
