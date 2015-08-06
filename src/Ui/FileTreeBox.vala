using Gtk;

namespace Ui {

  public class FileTreeBox {

    public FileTreeBox(bool checkable = false) {
      this.checkable = checkable;
      root = new DirEntry (this, "");
      file_selected_internal.connect ((entry)=>{
        // Update selection
        selection = entry;
      });
    }
    public FileEntry? selection;
    public signal void file_selected (FileEntry entry);
    protected signal void file_selected_internal (FileEntry entry);
    public signal void file_checked (string filename, Object data, bool checked);
    protected bool checkable;

    public class FileEntry {
      public FileEntry (FileTreeBox file_tree_box, string filename, bool check, Object data, DirEntry parent) {
        this.filename = filename;
        this.check = check;
        this.file_tree_box = file_tree_box;
        this.data = data;
        this.parent = parent;
      }
      public Widget get_widget() {
        if (file_tree_box.checkable) {
          var chk = new CheckButton.with_label (filename);
          chk.active = check;
          chk.toggled.connect (()=>{
            check = chk.active;
            file_tree_box.file_checked (filename, data, check);
          });
          return chk;
        } else
          return new Label (filename);
      }
      bool check;
      private weak FileTreeBox file_tree_box;
      public weak DirEntry parent;
      public string filename;
      public Object data;
      public string path;
    }

    public class DirEntry {
      public DirEntry (FileTreeBox file_tree_box, string dir) {
        expander = new Gtk.Expander(dir);
        if (dir != "") {
          expander.add (box_meta);
          box_meta.margin_left = 15;
        }
        box_meta.add (box_dirs);
        box_meta.add (listbox);

        // Deselect listbox if the child of another directory is selected
        file_tree_box.file_selected_internal.connect((file)=>{
          if (!(file in child_files))
            listbox.select_row (null);
        });

        listbox.row_selected.connect ((row)=>{
          if (row == null)
            return;
          var file = row.get_data<FileEntry>("fileentry");
          file_tree_box.file_selected_internal (file);
          file_tree_box.file_selected (file);
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
      public void deselect() {
        foreach (var child in child_dirs)
          child.deselect ();
        listbox.select_row (null);
      }
      public void select_child (FileEntry entry) {
        foreach (var row in listbox.get_children()) {
          if (row.get_data<FileEntry>("fileentry") == entry) {
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
      public void add_file (string[] path, string filename, Project.ProjectMember member, bool checked = false) {
        // If the path has been followed entirely, add file
        if (path.length == 0) {
          if (get_child_file (filename) == null) {
            child_files.add (new FileEntry (file_tree_box, filename, checked, member, this));
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
        child.add_file (path[1:path.length], filename, member, checked);
      }
      public void remove_child_file (FileEntry entry) {
        if (file_tree_box.selection == entry)
          file_tree_box.selection = null;

        child_files.remove (entry);
        update();
      }
      public FileEntry? get_entry (string[] path) {
        if (path.length == 1)
          return get_child_file (path[0]);
        // Pass on to child
        var child = get_child_dir (path[0]);
        if (child == null)
          return null;
        return child.get_entry (path[1:path.length]);
      }
    }

    private DirEntry root = null;
    public Widget update() {
      var row = new Gtk.ListBoxRow();
      return root.update();
    }
    public void deselect() {
      selection = null;
      root.deselect();
    }
    public void select(FileEntry entry) {
      entry.parent.select_child (entry);
    }
    public void add_file (string path, Project.ProjectMember member, bool checked = false) {
      var splt = path.split ("/");
      root.add_file (splt[0:splt.length - 1], splt[splt.length - 1], member, checked);
    }
    public FileEntry? get_entry (string file) {
      var splt = file.split ("/");
      return root.get_entry (splt);
    }
    public void remove_file (FileEntry entry) {
      entry.parent.remove_child_file (entry);
    }
  }

}
