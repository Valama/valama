using Gtk;

namespace Ui {

  public class FileTreeBox {

    public FileTreeBox() {
      root = new DirEntry (this, "");
      file_selected.connect ((filename, data)=>{
        // Deselect all ListBoxes except for filename
        selection_filename = filename;
        selection_data = data;
        root.deselect (filename);
      });
    }
    public string? selection_filename;
    public Object? selection_data;
    public signal void file_selected (string filename, Object data);

    private class FileEntry {
      public FileEntry (FileTreeBox file_tree_box, string filename, Object data) {
        this.filename = filename;
        this.file_tree_box = file_tree_box;
        this.data = data;
      }
      public Widget get_widget() {
        return new Label (filename);
      }
      private weak FileTreeBox file_tree_box;
      public string filename;
      public Object data;
    }

    private class DirEntry {
      public DirEntry (FileTreeBox file_tree_box, string dir) {
        expander = new Gtk.Expander(dir);
        if (dir != "") {
          expander.add (box_meta);
          box_meta.margin_left = 15;
        }
        box_meta.add (box_dirs);
        box_meta.add (listbox);

        listbox.row_selected.connect ((row)=>{
          if (row == null)
            return;
          var file = row.get_data<FileEntry>("fileentry");
          file_tree_box.file_selected (file.filename, file.data);
        });

        this.dir = dir;
        this.file_tree_box = file_tree_box;
      }
      private weak FileTreeBox file_tree_box;
      public string dir = "";
      private Gee.LinkedList<DirEntry?> child_dirs = new Gee.LinkedList<DirEntry?>();
      private Gee.LinkedList<FileEntry?> child_files = new Gee.LinkedList<FileEntry?>();

      private Gtk.Expander expander = null;
      private Gtk.ListBox listbox = new Gtk.ListBox();
      private Gtk.Box box_meta = new Gtk.Box (Orientation.VERTICAL, 0);
      private Gtk.Box box_dirs = new Gtk.Box (Orientation.VERTICAL, 0);

      public Widget update() {
        foreach (Widget widget in listbox.get_children())
          listbox.remove (widget);
        foreach (Widget widget in box_dirs.get_children())
          box_dirs.remove (widget);

        foreach (var dir in child_dirs) {
          box_dirs.add (dir.update());
        }
        foreach (var file in child_files) {
          var new_row = new ListBoxRow ();
          new_row.add (file.get_widget());
          new_row.set_data<FileEntry>("fileentry", file);
          listbox.add (new_row);
        }
        box_dirs.show_all();
        listbox.show_all();
        if (dir == "")
          return box_meta;
        else
          return expander;
      }
      public void deselect(string? except_file) {
        foreach (var child in child_dirs)
          child.deselect (except_file);
        if (except_file != null)
          if (get_child_file (except_file) != null)
            return;
        listbox.select_row (null);
      }
      public void select(string file) {
        foreach (var child in child_dirs)
          child.select (file);

        foreach (var row in listbox.get_children()) {
          if (row.get_data<FileEntry>("fileentry").filename == file) {
            listbox.select_row (row as ListBoxRow);
            return;
          }
        }
        listbox.select_row (null);
      }
      private FileEntry? get_child_file (string filename) {
        foreach (var child in child_files)
          if (child.filename == filename)
            return child;
        return null;
      }
      private DirEntry? get_child_dir (string dir) {
        foreach (var child in child_dirs)
          if (child.dir == dir)
            return child;
        return null;
      }
      public void add_file (string[] path, string filename, Project.ProjectMember member) {
        // If the path has been followed entirely, add file
        if (path.length == 0) {
          if (get_child_file (filename) == null) {
            child_files.add (new FileEntry (file_tree_box, filename, member));
            update();
          }
          return;
        }
        // Otherwise, find or create next subdirectory entry
        var child = get_child_dir (path[0]);
        if (child == null) {
          child = new DirEntry (file_tree_box, path[0]);
          child_dirs.add (child);
          update();
        }
        child.add_file (path[1:path.length], filename, member);
      }
      public void remove_file (string[] path, string filename) {
        // If the path has been followed entirely, remove file and update UI
        if (path.length == 0) {
          var file_entry = get_child_file (filename);
          child_files.remove (file_entry);
          update();
          return;
        }
        // Otherwise, pass on to child
        var child = get_child_dir (path[0]);
        if (child == null)
          return;
        child.remove_file (path[1:path.length], filename);
        // And if child has no children itself, remove it
        if (child.child_files.size == 0 && child.child_dirs.size == 0) {
          child_dirs.remove (child);
          update();
        }
      }
    }

    private DirEntry root = null;
    public Widget update() {
      var row = new Gtk.ListBoxRow();
      return root.update();
    }
    public void deselect(string? except_file) {
      root.deselect(except_file);
    }
    public void select(string file) {
      root.select(file);
    }
    public void add_file (string path, Project.ProjectMember member) {
      var splt = path.split ("/");
      root.add_file (splt[0:splt.length - 1], path, member);
    }
    public void remove_file (string path) {
      var splt = path.split ("/");
      root.remove_file (splt[0:splt.length - 1], path);
    }
  }

}
