namespace Project {

  public enum ConditionRelation {
    GREATER,
    EQUAL,
    LESSER;
    
    public string toString() {
      if (this == GREATER)
        return "greater";
      if (this == EQUAL)
        return "equal";
      if (this == LESSER)
        return "lesser";
      return "UNKNOWN";
    }
    public static ConditionRelation fromString(string s) {
      if (s == "greater")
        return GREATER;
      if (s == "equal")
        return EQUAL;
      if (s == "lesser")
        return LESSER;
      return EQUAL;
    }
  }

  public class Condition {
    public string library;
    public string version;
    public ConditionRelation relation;

    public void load (Xml.Node* node) {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "library")
          library = prop->children->content;
        else if (prop->name == "version")
          version = prop->children->content;
        else if (prop->name == "relation")
          relation = ConditionRelation.fromString(prop->children->content);
      }
    }
    public void save (Xml.TextWriter writer) {
      writer.start_element ("condition");
      writer.write_attribute ("library", library);
      writer.write_attribute ("version", version);
      writer.write_attribute ("relation", relation.toString());
      writer.end_element();
    }
  }

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

  public class Dependency {
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
