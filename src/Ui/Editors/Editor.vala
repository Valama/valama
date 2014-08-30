namespace Ui {

  public abstract class Editor : Viewer {
  
    public Project.ProjectMember member;
    public override void save (Xml.TextWriter writer) {
      writer.start_element ("editor");
      writer.write_attribute ("memberid", member.id);
      save_internal (writer);
      writer.end_element();
    }
  
  }

}
