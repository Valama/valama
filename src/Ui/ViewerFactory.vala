namespace Ui {
  public enum EnumViewer {
    CLASSDIAGRAM,
    UNKNOWN;

    public string toString() {
      if (this == CLASSDIAGRAM)
        return "classdiagram";
      return "UNKNOWN";
    }
    public static EnumViewer fromString(string s) {
      if (s == "classdiagram")
        return CLASSDIAGRAM;
      return UNKNOWN;
    }

  }

  public class ViewerFactory {
    public static Viewer? createViewer (EnumViewer type) {
      Viewer new_viewer = null;
      if (type == EnumViewer.CLASSDIAGRAM)
        new_viewer = new ViewerClassDiagram();

      return new_viewer;
    }
  
  }
}
