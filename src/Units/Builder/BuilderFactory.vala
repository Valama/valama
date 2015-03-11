namespace Builder {
  public enum EnumBuildsystem {
    CUSTOM,
    AUTOVALA,
    VALAMA,
    WAF;

    public static EnumBuildsystem[] to_array() {
      return new EnumBuildsystem[]  {VALAMA, CUSTOM, AUTOVALA, WAF};
    }

    public string toString() {
      if (this == CUSTOM)
        return "custom";
      if (this == AUTOVALA)
        return "autovala";
      if (this == VALAMA)
        return "valama";
      if (this == WAF)
        return "waf";
      return "";
    }
    public static EnumBuildsystem fromString(string s) {
      if (s == "custom")
        return CUSTOM;
      if (s == "autovala")
        return AUTOVALA;
      if (s == "valama")
        return VALAMA;
      if (s == "waf")
        return WAF;
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
      else if (type == EnumBuildsystem.WAF)
        new_builder = new Waf();

      new_builder.target = target;
      new_builder.set_defaults();
      return new_builder;
    }
  
  }
}
