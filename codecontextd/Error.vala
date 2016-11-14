public enum EnumReportType {
    ERROR = 0,
    WARNING = 1,
    DEPRECATED = 2,
    EXPERIMENTAL = 3,
    NOTE = 4;

  	public static EnumReportType from_int (int val) {
  	  switch (val) {
  	    case 0:
          return ERROR;
  	    case 1:
          return WARNING;
  	    case 2:
          return DEPRECATED;
  	    case 3:
          return EXPERIMENTAL;
  	    case 4:
          return NOTE;
        default:
            assert_not_reached();
      }
    }

    /*public const ReportType ALL = ERROR | WARNING | DEPRECATED | EXPERIMENTAL | NOTE;

    public string? to_string() {
        switch (this) {
            case ERROR:
                return ("Error");
            case WARNING:
                return ("Warning");
            case DEPRECATED:
                return ("Deprecated");
            case EXPERIMENTAL:
                return ("Experimental");
            case NOTE:
                return ("Note");
            default:
                assert_not_reached();
        }
    }*/
}

private string get_symbol_type_name (Vala.Symbol symbol) {
    if (symbol is Vala.Class)        return "class";
    if (symbol is Vala.Constant)     return "constant";
    if (symbol is Vala.Delegate)     return "delegate";
    if (symbol is Vala.Enum)         return "enum";
    if (symbol is Vala.EnumValue) return "enum_value";
    if (symbol is Vala.ErrorCode)    return "error_code";
    if (symbol is Vala.ErrorDomain)  return "error_domain";
    if (symbol is Vala.Variable)     return "field";
    if (symbol is Vala.Interface)    return "interface";
    if (symbol is Vala.Method)       return "method";
    if (symbol is Vala.Namespace)    return "namespace";
    if (symbol is Vala.Property)     return "property";
    if (symbol is Vala.Signal)  return "signal";
    if (symbol is Vala.Struct)       return "struct";
    return "";
}

public class CompletionProposal {

  /*public CompletionProposal (string symbol_name, string symbol_name_full, string symbol_type, int replace_length) {
    this.symbol_name = symbol_name;
    this.symbol_name_full = symbol_name_full;
    this.replace_length = replace_length;
    this.symbol_type = symbol_type;
  }*/
  public CompletionProposal (Vala.Symbol symbol, int replace_length) {
    this.symbol_name = symbol.name;
    this.symbol_name_full = symbol.get_full_name();
    this.replace_length = replace_length;
    this.symbol_type = get_symbol_type_name(symbol);
  }

  public CompletionProposal.deserialize (string data) {
    Regex r = /^(?P<sb>.*)\<sbf(?P<sbf>.*)\<sbt(?P<sbt>.*)\<len(?P<len>.*)$/;
    MatchInfo info;
    r.match (data, 0, out info);

    symbol_name = info.fetch_named("sb");
    symbol_name_full = info.fetch_named("sbf");
    symbol_type = info.fetch_named("sbt");
    replace_length = int.parse(info.fetch_named("len"));
  }

  public string serialize() {
    return symbol_name + "<sbf" + symbol_name_full + "<sbt" + symbol_type + "<len" + replace_length.to_string();
  }

  public string symbol_name;
  public string symbol_name_full;
  public int replace_length;
  public string symbol_type;

}

public class SourceLocation {
  public SourceLocation (Vala.SourceLocation source_location) {
    line = source_location.line;
    column = source_location.column;
  }
  public SourceLocation.deserialize (string data) {
    Regex r = /^(?P<line>.*)\|\|(?P<column>.*)$/;
    MatchInfo info;
    r.match (data, 0, out info);

    line = int.parse(info.fetch_named("line"));
    column = int.parse(info.fetch_named("column"));
  }
  public string serialize() {
    return line.to_string() + "||" + column.to_string();
  }
  public int line;
  public int column;
}

public class SourceReference : Object {
  public SourceReference (Vala.SourceReference source_reference) {
    file = source_reference.file.filename;
    begin = new SourceLocation (source_reference.begin);
    end = new SourceLocation (source_reference.end);
  }
  public SourceReference.deserialize (string data) {
    Regex r = /^(?P<file>.*)\<beg(?P<begin>.*)\<end(?P<end>.*)$/;
    MatchInfo info;
    r.match (data, 0, out info);

    file = info.fetch_named("file");
    begin = new SourceLocation.deserialize(info.fetch_named("begin"));
    end = new SourceLocation.deserialize(info.fetch_named("end"));
  }
  public string serialize() {
    return file.escape("") + "<beg" + begin.serialize() + "<end" + end.serialize();
  }
  public string file;
  public SourceLocation begin;
  public SourceLocation end;
}

public class CompilerError : Object {
    public SourceReference source;
    public string message;
    public EnumReportType type;

    public CompilerError (Vala.SourceReference? source, string message, EnumReportType type) {
        this.source = new SourceReference(source);
        this.message = message;
        this.type = type;
    }
    public string serialize() {
        return message.escape("") + "<tpe" + ((int)type).to_string() + "<src" + source.serialize();
    }
    public CompilerError.deserialize(string data) {
        Regex r = /^(?P<word>.*)\<tpe(?P<rest>.*)\<src(?P<source>.*)$/;
        MatchInfo info;
        r.match (data, 0, out info);

        message = info.fetch_named("word");
        source = new SourceReference.deserialize(info.fetch_named("source"))  ;
        type = EnumReportType.from_int(int.parse(info.fetch_named("rest")));
    }
}

