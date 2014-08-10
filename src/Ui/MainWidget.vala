namespace Ui {

  public class MainWidget : Object {
  
    public Gtk.Widget widget;

    public Project.Project project;
    
    public EditorViewer editor_viewer = new EditorViewer();
    public ProjectStructure project_structure = new ProjectStructure();
    public MainToolbar main_toolbar = new MainToolbar();
    private Gee.ArrayList<Element> elements = new Gee.ArrayList<Element>();
    
    public MainWidget(Project.Project project) {
      this.project = project;

      // Initialize all elements
      elements.add (main_toolbar);
      elements.add (editor_viewer);
      elements.add (project_structure);
      
      foreach (var element in elements) {
        element.main_widget = this;
        element.init();
      }
      
      // Build main UI out of elements
      var grid = new Gtk.Grid();
      grid.attach (main_toolbar.widget, 0, 0, 2, 1);
      grid.attach (project_structure.widget, 0, 1, 1, 1);
      grid.attach (editor_viewer.widget, 1, 1, 1, 1);
      grid.show();
      widget = grid;
    }
    public void dispose() {
      foreach (var element in elements)
        element.dispose();
    }
  }

}
