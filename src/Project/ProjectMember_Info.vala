namespace Project {

  public class Author {
    public string name;
    public string mail;
  }

  public class ProjectMemberInfo : ProjectMember {
  
    public string name = null;
    public int major = -1;
    public int minor = -1;
    public int patch = -1;
    public Gee.ArrayList <Author> authors = new Gee.ArrayList <Author>();
    
    internal override void load_internal (Xml.Node* node) throws ProjectError {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "name")
          name = prop->children->content;
        if (prop->name == "major")
          major = int.parse(prop->children->content);
        if (prop->name == "minor")
          minor = int.parse(prop->children->content);
        if (prop->name == "patch")
          patch = int.parse(prop->children->content);
      }
      for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
        if (iter->type != Xml.ElementType.ELEMENT_NODE)
          continue;
        if (iter->name != "author")
          continue;
        var author = new Author();
        for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
          if (prop->name == "name")
            author.name = prop->children->content;
          else if (prop->name == "mail")
            author.mail = prop->children->content;
        }
        authors.add (author);
      }

      if (major == -1 || minor == -1 || patch == -1)
        throw new ProjectError.CORRUPT_MEMBER("version attribute missing in info member");
      if (name == null)
        throw new ProjectError.CORRUPT_MEMBER("name attribute missing in info member");
    }
    internal override void save_internal (Xml.TextWriter writer) {
      writer.write_attribute ("name", name);
      writer.write_attribute ("major", major.to_string());
      writer.write_attribute ("minor", minor.to_string());
      writer.write_attribute ("patch", patch.to_string());
      foreach (Author author in authors) {
        writer.start_element ("author");
        writer.write_attribute ("name", author.name);
        writer.write_attribute ("mail", author.mail);
        writer.end_element();
      }
    }
    public override bool create () {
      return false;
    }
    internal override Ui.Editor createEditor_internal(Ui.MainWidget main_widget) {
      return new Ui.EditorInfo(this, main_widget);
    }
    public override string getTitle() {
      return name;
    }
  }

}
