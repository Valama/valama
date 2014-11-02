namespace Ui {

  public class MainWidget : Object {
  
    public Gtk.Widget widget;

    public Project.Project project;
    
    public EditorViewer editor_viewer = new EditorViewer();
    public ProjectStructure project_structure = new ProjectStructure();
    public MainToolbar main_toolbar = new MainToolbar();
    public ErrorList error_list = new ErrorList();
    public Units.CodeContextProvider code_context_provider = new Units.CodeContextProvider();
    public Units.ErrorMarker error_marker = new Units.ErrorMarker();
    public Units.SourceBufferManager source_buffer_manager = new Units.SourceBufferManager();
    public Units.CompletionProvider completion_provider = new Units.CompletionProvider();
    public Units.Builder builder = new Units.Builder();

    private Gee.ArrayList<Units.Unit> units = new Gee.ArrayList<Units.Unit>();
    
    public MainWidget(Project.Project project) {
      this.project = project;

      // Initialize all elements
      units.add (main_toolbar);
      units.add (editor_viewer);
      units.add (project_structure);
      units.add (code_context_provider);
      units.add (error_list);
      units.add (error_marker);
      units.add (source_buffer_manager);
      units.add (completion_provider);
      units.add (builder);
      
      foreach (var unit in units) {
        unit.main_widget = this;
        unit.init();
      }
      
      // Build main UI out of elements
      var grid = new Gtk.Grid();
      grid.attach (main_toolbar.widget, 0, 0, 2, 1);
      grid.attach (project_structure.widget, 0, 1, 1, 2);
      grid.attach (editor_viewer.widget, 1, 1, 1, 1);
      grid.attach (error_list.widget, 1, 2, 1, 1);
      grid.show();
      widget = grid;
    }
    public void destroy() {
      foreach (var unit in units)
        unit.destroy();
    }
  }

}
