namespace Project {
  public enum EnumProjectMember {
    VALASOURCE,
    TARGET,
    INFO,
    CLASS_DIAGRAM,
    UNKNOWN;

    public string toString() {
      if (this == VALASOURCE)
        return "valasource";
      if (this == TARGET)
        return "target";
      if (this == INFO)
        return "info";
      if (this == CLASS_DIAGRAM)
        return "classdiagram";
      return "UNKNOWN";
    }
    public static EnumProjectMember fromString(string s) {
      if (s == "valasource")
        return VALASOURCE;
      if (s == "target")
        return TARGET;
      if (s == "info")
        return INFO;
      if (s == "classdiagram")
        return CLASS_DIAGRAM;
      return UNKNOWN;
    }

  }

  public class ProjectMemberFactory {
    public static ProjectMember? createMember (EnumProjectMember type, Project project) {
      ProjectMember new_member = null;
      if (type == EnumProjectMember.VALASOURCE)
        new_member = new ProjectMemberValaSource();
      else if (type == EnumProjectMember.TARGET)
        new_member = new ProjectMemberTarget();
      else if (type == EnumProjectMember.INFO)
        new_member = new ProjectMemberInfo();
      else if (type == EnumProjectMember.CLASS_DIAGRAM)
        new_member = new ProjectMemberClassDiagram();
      
      if (new_member != null)
        new_member.project = project;
      return new_member;
    }
  
  }
}
