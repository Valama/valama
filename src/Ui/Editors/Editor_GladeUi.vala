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
      title = member.filename;

		  glade_project = Glade.Project.load (member.filename);
		  Glade.App.add_project (glade_project);
		  design_view = new Glade.DesignView (glade_project);
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
      
      var grid = new Gtk.Grid();
      grid.attach (inspector, 0, 0, 1, 1);
      grid.attach (design_view, 1, 0, 1, 1);
      grid.attach (palette, 2, 0, 1, 1);
      grid.attach (editor, 3, 0, 1, 1);
      grid.attach (signals, 4, 0, 1, 1);

      widget = grid;
      widget.show_all();
    }

    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {
    }
    internal override void destroy_internal() {
      Glade.App.remove_project (glade_project);
    }
  }

}
