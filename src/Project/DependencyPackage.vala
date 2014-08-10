namespace Project {

  public class DependencyPackage : Dependency {
    public override void load (Xml.Node* node) {

    }
    public override void save (Xml.TextWriter writer) {
      writer.start_element ("package");
      writer.end_element();
    }
  }
}
