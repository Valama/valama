namespace Project {
  public enum EnumProjectMember {
    VALASOURCE,
    TARGET,
    INFO,
    CLASS_DIAGRAM,
    GETTEXT,
    GLADEUI,
    GRESOURCE,
    DATA,
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
      if (this == GLADEUI)
        return "gladeui";
      if (this == GRESOURCE)
        return "gresource";
      if (this == DATA)
        return "data";
      if (this == GETTEXT)
        return "gettext";
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
      if (s == "gladeui")
        return GLADEUI;
      if (s == "gresource")
        return GRESOURCE;
      if (s == "data")
        return DATA;
      if (s == "gettext")
        return GETTEXT;
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
      else if (type == EnumProjectMember.GETTEXT)
        new_member = new ProjectMemberGettext();
      else if (type == EnumProjectMember.GLADEUI)
        new_member = new ProjectMemberGladeUi();
      else if (type == EnumProjectMember.GRESOURCE)
        new_member = new ProjectMemberGResource();
      else if (type == EnumProjectMember.DATA)
        new_member = new ProjectMemberData();
      
      if (new_member != null)
        new_member.project = project;
      return new_member;
    }
  
  }
}
