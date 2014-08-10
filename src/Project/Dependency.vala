namespace Project {

  public abstract class Dependency {
    public abstract void load (Xml.Node* node);
    public abstract void save (Xml.TextWriter writer);
 }
}
