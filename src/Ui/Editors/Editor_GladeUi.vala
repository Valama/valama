using Gtk;

namespace Ui {

  public class EditorGladeUi : Editor {
  
    public Gtk.SourceView sourceview = new Gtk.SourceView ();
  
    private Project.ProjectMemberGladeUi my_member = null;


    private Glade.Project glade_project = new Glade.Project();
    private Glade.Inspector inspector = new Glade.Inspector();
    private Glade.DesignView design_view;
    private Glade.Palette palette = new Glade.Palette();
    private Glade.Editor editor = new Glade.Editor();
    private Glade.SignalEditor signals = new Glade.SignalEditor();
  
    public EditorGladeUi(Project.ProjectMemberGladeUi member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      my_member = member as Project.ProjectMemberGladeUi;
      title = member.getTitle();

      var grid = new Gtk.Grid();
      Glade.App.set_window (main_widget.window);

      glade_project = Glade.Project.load (member.file.get_abs());
      design_view = new Glade.DesignView (glade_project);
      Glade.App.add_project (glade_project);
      inspector.project = glade_project;
      palette.project = glade_project;

      inspector.selection_changed.connect (() => {
        var w = inspector.get_selected_items().nth_data (0);
        w.show();
        editor.load_widget (w);
      });
      inspector.item_activated.connect (() => {
        var w = inspector.get_selected_items().nth_data (0);
        w.show();
        editor.load_widget (w);
        signals.load_widget (w);
      });
      
      var paned_palette_design_view = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
      paned_palette_design_view.add1 (palette);
      paned_palette_design_view.add2 (design_view);
      paned_palette_design_view.expand = true;
      palette.show();
      design_view.show();

      design_view.expand = true;
      grid.attach (paned_palette_design_view, 0, 0, 1, 1);
      grid.attach (inspector, 1, 0, 1, 1);
      grid.attach (editor, 2, 0, 1, 1);
      grid.attach (signals, 3, 0, 1, 1);

      editor.show();
      grid.expand = true;

      widget = grid;
      widget.show_all();
    }

    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {
    }
    internal override void destroy_internal() {
      glade_project.save (my_member.file.get_abs());
      Glade.App.remove_project (glade_project);
    }
  }

}
