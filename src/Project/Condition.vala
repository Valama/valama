namespace Project {

  public enum ConditionRelation {
    GREATER,
    GREATER_EQUAL,
    EQUAL,
    LESSER_EQUAL,
    LESSER,
    EXISTS;
    
    public string toString() {
      if (this == GREATER)
        return "greater";
      if (this == GREATER_EQUAL)
        return "greater_equal";
      if (this == EQUAL)
        return "equal";
      if (this == LESSER_EQUAL)
        return "lesser_equal";
      if (this == LESSER)
        return "lesser";
      if (this == EXISTS)
        return "exists";
      return "UNKNOWN";
    }
    public static ConditionRelation fromString(string s) {
      if (s == "greater")
        return GREATER;
      if (s == "greater_equal")
        return GREATER_EQUAL;
      if (s == "equal")
        return EQUAL;
      if (s == "lesser_equal")
        return LESSER_EQUAL;
      if (s == "lesser")
        return LESSER;
      if (s == "exists")
        return EXISTS;
      return EQUAL;
    }
  }

  public class Condition : Object {
    public string library = "";
    public string version = "";
    public ConditionRelation relation = ConditionRelation.EXISTS;

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
}
