namespace Builder {
  public enum EnumBuildsystem {
    CUSTOM,
    AUTOVALA;

    public static EnumBuildsystem[] to_array() {
      return new EnumBuildsystem[] {CUSTOM, AUTOVALA};
    }

    public string toString() {
      if (this == CUSTOM)
        return "custom";
      if (this == AUTOVALA)
        return "autovala";
      return "";
    }
    public static EnumBuildsystem fromString(string s) {
      if (s == "custom")
        return CUSTOM;
      if (s == "autovala")
        return AUTOVALA;
      return CUSTOM;
    }

  }

  public class BuilderFactory {
    public static Builder? create_member (EnumBuildsystem type) {
      Builder new_builder = null;
      if (type == EnumBuildsystem.CUSTOM)
        new_builder = new Custom();
      else if (type == EnumBuildsystem.AUTOVALA)
        new_builder = new Autovala();

      return new_builder;
    }
  
  }
}
