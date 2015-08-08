using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/MainWidget.glade")]
  private class MainWidgetTemplate : Box {
  	[GtkChild]
  	public Alignment algn_project_structure;
  	[GtkChild]
  	public Alignment algn_viewer;
  	[GtkChild]
  	public Alignment algn_errors;
  	[GtkChild]
  	public Alignment algn_console;
  }

  public class MainWidget : Object {
  
    public Gtk.Widget widget;
    public weak Gtk.Window window;

    public Project.Project project;

    private MainWidgetTemplate template = new MainWidgetTemplate();
    
    public EditorViewer editor_viewer = new EditorViewer();
    public ProjectStructure project_structure = new ProjectStructure();
    public MainToolbar main_toolbar = new MainToolbar();
    public ErrorList error_list = new ErrorList();
    public ConsoleView console_view = new ConsoleView();
    public Units.CodeContextProvider code_context_provider = new Units.CodeContextProvider();
    public Units.ErrorMarker error_marker = new Units.ErrorMarker();
    public Units.SourceBufferManager source_buffer_manager = new Units.SourceBufferManager();
    public Units.CompletionProvider completion_provider = new Units.CompletionProvider();
    public Units.InstalledLibrariesProvider installed_libraries_provider = new Units.InstalledLibrariesProvider();

    private Gee.ArrayList<Units.Unit> units = new Gee.ArrayList<Units.Unit>();
    
    public MainWidget(Project.Project project, Gtk.Window window) {
      this.project = project;
      this.window = window;

      // Initialize all elements
      units.add (main_toolbar);
      units.add (editor_viewer);
      units.add (project_structure);
      units.add (code_context_provider);
      units.add (error_list);
      units.add (error_marker);
      units.add (source_buffer_manager);
      units.add (completion_provider);
      units.add (installed_libraries_provider);
      units.add (console_view);

      foreach (var unit in units) {
        unit.main_widget = this;
        unit.init();
      }

      // Add elements to main UI
      window.set_titlebar (main_toolbar.widget);
      template.algn_project_structure.add(project_structure.widget);
      template.algn_viewer.add(editor_viewer.widget);
      template.algn_errors.add(error_list.widget);
      template.algn_console.add(console_view.widget);

      widget = template;
    }
    public void destroy() {
      project.save ();
      foreach (var unit in units)
        unit.destroy();
    }
  }

}
