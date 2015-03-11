namespace Project {

  public enum DependencyType {
    VAPI,
    PACKAGE;
    
    public string toString() {
      if (this == PACKAGE)
        return "package";
      if (this == VAPI)
        return "vapi";
      return "UNKNOWN";
    }
    public static DependencyType fromString(string s) {
      if (s == "package")
        return PACKAGE;
      if (s == "vapi")
        return VAPI;
      return PACKAGE;
    }
  }

  public class Dependency : Object {
    public string library;
    public DependencyType type;
    public Gee.ArrayList<Condition> conditions = new Gee.ArrayList<Condition>();
    public void load (Xml.Node* node) {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "type")
          type = DependencyType.fromString(prop->children->content);
        else if (prop->name == "library")
          library = prop->children->content;
      }
      for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;
        if (iter->name == "condition") {
          var cond = new Condition();
          cond.load (iter);
          conditions.add (cond);
        }
      }
    }
    public void save (Xml.TextWriter writer) {
      writer.start_element ("dependency");
      writer.write_attribute ("type", type.toString());
      writer.write_attribute ("library", library);
      foreach (var cond in conditions)
        cond.save (writer);
      writer.end_element();
    }
 }
}
