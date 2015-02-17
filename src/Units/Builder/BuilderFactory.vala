namespace Builder {
  public enum EnumBuilder {
    CUSTOM,
    AUTOVALA;

    public static EnumBuilder[] to_array() {
      return new EnumBuilder[] {CUSTOM, AUTOVALA};
    }

    public string toString() {
      if (this == CUSTOM)
        return "custom";
      if (this == AUTOVALA)
        return "autovala";
      return "";
    }
    public static EnumBuilder fromString(string s) {
      if (s == "custom")
        return CUSTOM;
      if (s == "autovala")
        return AUTOVALA;
      return CUSTOM;
    }

  }

  public class BuilderFactory {
    /*public static ProjectMember? createMember (EnumBuilder type, Project project) {
      ProjectMember new_member = null;
      if (type == EnumProjectMember.VALASOURCE)
        new_member = new ProjectMemberValaSource();
      else if (type == EnumProjectMember.TARGET)
        new_member = new ProjectMemberTarget();
      else if (type == EnumProjectMember.INFO)
        new_member = new ProjectMemberInfo();
      else if (type == EnumProjectMember.CLASS_DIAGRAM)
        new_member = new ProjectMemberClassDiagram();
      else if (type == EnumProjectMember.GLADEUI)
        new_member = new ProjectMemberGladeUi();
      
      if (new_member != null)
        new_member.project = project;
      return new_member;
    }*/
  
  }
}
