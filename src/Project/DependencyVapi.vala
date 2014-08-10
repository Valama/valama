namespace Project {

  public class DependencyVapi : Dependency {
    public override void load (Xml.Node* node) {

    }
    public override void save (Xml.TextWriter writer) {
      writer.start_element ("vapi");
      writer.end_element();
    }
  }
}
