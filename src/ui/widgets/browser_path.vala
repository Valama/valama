using Gtk;

public class BrowserPath {
    TreePath path;
    
    public BrowserPath (TreePath path) {
        this.path = path;
    }
    
    public string to_string() {
        return path.to_string();
    }
    
    public int get (int index) {
        return path.get_indices()[index];
    }
    
    public BrowserPathType path_type {
        get {
            if (this[0] == 0 && this[1] == 0)
                return BrowserPathType.SOURCE;
            if (this[0] == 0 && this[1] == 1)
                return BrowserPathType.PACKAGE;
            if (this[0] == 1)
                return BrowserPathType.UI;
            if (this[0] == 2)
                return BrowserPathType.BUILDSYSTEM;
            if (this[0] == 2)
                return BrowserPathType.DATA;
            return BrowserPathType.NONE;
        }
    }
    
    public int size {
        get {
            return path.get_depth();
        }
    }
}

public enum BrowserPathType {
    NONE, SOURCE, PACKAGE, UI, BUILDSYSTEM, DATA
}
