namespace Project {
  public enum EnumProjectMember {
    VALASOURCE,
    TARGET,
    INFO,
    UNKNOWN;

    public string toString() {
      if (this == VALASOURCE)
        return "valasource";
      if (this == TARGET)
        return "target";
      if (this == INFO)
        return "info";
      return "UNKNOWN";
    }
    public static EnumProjectMember fromString(string s) {
      if (s == "valasource")
        return VALASOURCE;
      if (s == "target")
        return TARGET;
      if (s == "info")
        return INFO;
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
      
      if (new_member != null)
        new_member.project = project;
      return new_member;
    }
  
  }
}
