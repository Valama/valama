namespace Builder {
  public enum EnumBuildsystem {
    CUSTOM,
    AUTOVALA,
    VALAMA;

    public static EnumBuildsystem[] to_array() {
      return new EnumBuildsystem[]  {VALAMA, CUSTOM, AUTOVALA};
    }

    public string toString() {
      if (this == CUSTOM)
        return "custom";
      if (this == AUTOVALA)
        return "autovala";
      if (this == VALAMA)
        return "valama";
      return "";
    }
    public static EnumBuildsystem fromString(string s) {
      if (s == "custom")
        return CUSTOM;
      if (s == "autovala")
        return AUTOVALA;
      if (s == "valama")
        return VALAMA;
      return CUSTOM;
    }

  }

  public class BuilderFactory {
    public static Builder? create_member (EnumBuildsystem type, Project.ProjectMemberTarget target) {
      Builder new_builder = null;
      if (type == EnumBuildsystem.CUSTOM)
        new_builder = new Custom();
      else if (type == EnumBuildsystem.AUTOVALA)
        new_builder = new Autovala();
      else if (type == EnumBuildsystem.VALAMA)
        new_builder = new Valama();

      new_builder.target = target;
      return new_builder;
    }
  
  }
}
