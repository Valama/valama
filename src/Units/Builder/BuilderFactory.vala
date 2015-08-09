namespace Builder {
  public enum EnumBuildsystem {
    CUSTOM,
    CMAKE,
    AUTOVALA,
    VALAMA,
    WAF,
    AUTOTOOLS;

    public static EnumBuildsystem[] to_array() {
      return new EnumBuildsystem[]  {CMAKE, VALAMA, CUSTOM, AUTOVALA, WAF, AUTOTOOLS};
    }

    public string toString() {
      var klass = (EnumClass)typeof (EnumBuildsystem).class_ref();
      var eval = klass.get_value (this);
      return eval == null ? "" : eval.value_nick;
    }
    public static EnumBuildsystem fromString(string s) {
      var klass = (EnumClass)typeof (EnumBuildsystem).class_ref();
      var eval = klass.get_value_by_nick (s);
      return eval == null ? CUSTOM : (EnumBuildsystem)eval.value;
    }

  }

  public class BuilderFactory {
    public static Builder? create_member (EnumBuildsystem type, Project.ProjectMemberTarget target) {
      Builder new_builder = null;
      if (type == EnumBuildsystem.CMAKE)
        new_builder = new CMake();
      else if (type == EnumBuildsystem.CUSTOM)
        new_builder = new Custom();
      else if (type == EnumBuildsystem.AUTOVALA)
        new_builder = new Autovala();
      else if (type == EnumBuildsystem.VALAMA)
        new_builder = new Valama();
      else if (type == EnumBuildsystem.WAF)
        new_builder = new Waf();
      else if (type == EnumBuildsystem.AUTOTOOLS)
		new_builder = new Autotools();

      new_builder.target = target;
      new_builder.set_defaults();
      return new_builder;
    }
  
  }
}
