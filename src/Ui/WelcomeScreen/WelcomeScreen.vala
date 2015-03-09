using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/WelcomeScreen/RecentEntry.glade")]
  private class RecentEntryTemplate : ListBoxRow {
  	[GtkChild]
  	public Label lbl_project_path;
  	[GtkChild]
  	public Label lbl_project_name;
  	[GtkChild]
  	public Label lbl_project_last_edited;
  	
  	public string project_file_path;
  }
 
  [GtkTemplate (ui = "/src/Ui/WelcomeScreen/WelcomeScreen.glade")]
  private class WelcomeScreenTemplate : Box {
  	[GtkChild]
  	public ListBoxRow row_new_project;
  	[GtkChild]
  	public ListBoxRow row_open_project;
  	[GtkChild]
  	public ListBox list_actions;
  	[GtkChild]
  	public ListBox list_recent_projects;
  	[GtkChild]
  	public Button btn_quit;
  	[GtkChild]
  	public Label lbl_no_recent_projects;
  }

  public class WelcomeScreen : Object {

    public Gtk.Widget widget;

    public signal void project_selected (Project.Project project);

    private WelcomeScreenTemplate template = new WelcomeScreenTemplate();

    public WelcomeScreen() {

      template.btn_quit.clicked.connect (Gtk.main_quit);

      // Temporary testing entry
      var recent_entry = new RecentEntryTemplate();
      recent_entry.lbl_project_name.label = "Test";
      recent_entry.project_file_path = "valama.vlp";
      template.list_recent_projects.add (recent_entry);

      // Handle selection of recent project
      template.list_recent_projects.row_activated.connect ((row)=>{
        if (row == null)
          return;
        var row_temp = row as RecentEntryTemplate;
        var project = new Project.Project();
        project.load (row_temp.project_file_path);
        project_selected (project);
      });

      // Handle selection of actions
      template.list_actions.row_activated.connect ((row)=>{
        if (row == null)
          return;
        if (template.list_actions.get_selected_row() == template.row_open_project) {
          var file_chooser = new Gtk.FileChooserDialog ("Open Project", null,
                                        Gtk.FileChooserAction.OPEN,
                                        Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                        Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
          if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
            var project = new Project.Project();
            project.load (file_chooser.get_file().get_path());
            project_selected (project);
          }
          file_chooser.destroy ();
        } else if (template.list_actions.get_selected_row() == template.row_new_project) {
          var template_chooser = new TemplateSelector();
          if (template_chooser.run () == Gtk.ResponseType.ACCEPT) {

            // Install to selected directory
            var proj_dir = template_chooser.directory + "/" + template_chooser.project_name;
            var project = template_chooser.template.install (template_chooser.project_name, proj_dir);

            project_selected (project);
          }
          template_chooser.destroy ();
        }
      });

      widget = template;
    }

  }

}
