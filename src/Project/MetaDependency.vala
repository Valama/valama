namespace Project {

  public class MetaDependency {

    public string name = "";

    public Gee.LinkedList<Dependency> dependencies = new Gee.LinkedList<Dependency>();

    public void show_edit_dialog() {

    }

    public void load (Xml.Node* node) {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "name")
          name = prop->children->content;
      }
      for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;

        Dependency dep;
        if (iter->name == "vapi")
          dep = new DependencyVapi();
        else if (iter->name == "package")
          dep = new DependencyPackage();
        else
          continue;
        dep.load (iter);
        dependencies.add (dep);
      }
    }
    public void save (Xml.TextWriter writer) {
      writer.write_attribute ("name", name);
      foreach (var dep in dependencies)
        dep.save (writer);
    }

  }
}
