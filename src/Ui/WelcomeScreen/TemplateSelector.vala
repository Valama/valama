using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/WelcomeScreen/TemplateSelector.glade")]
  private class TemplateSelectorTemplate : Box {
    public TemplateSelectorTemplate (ProjectTemplateProvider provider) {
      foreach (var template in provider.templates) {
        list_templates.add (new TemplateSelectorEntryTemplate(template));
      }
    }
  	[GtkChild]
  	public Label lbl_description;
  	[GtkChild]
  	public ListBox list_templates;
  	[GtkChild]
  	public Entry ent_project_name;
  	[GtkChild]
  	public FileChooserButton fch_dir;
  }

  [GtkTemplate (ui = "/src/Ui/WelcomeScreen/TemplateSelectorEntry.glade")]
  private class TemplateSelectorEntryTemplate : ListBoxRow {
    public TemplateSelectorEntryTemplate (ProjectTemplate template) {
      this.template = template;
      lbl_name.label = template.name;
    }
    public ProjectTemplate template;
  	[GtkChild]
  	public Label lbl_name;
  	[GtkChild]
  	public Image img_icon;
  }

  public class TemplateSelector : Dialog {

    private TemplateSelectorTemplate ui_template;
    public ProjectTemplate? template = null;
    public string project_name = null;
    public string directory = null;

    public TemplateSelector() {
      var provider = new ProjectTemplateProvider();
      ui_template = new TemplateSelectorTemplate(provider);

      add_button (_("_Cancel"), ResponseType.CANCEL);
      add_button (_("_Open"), ResponseType.ACCEPT);
      set_default_response (ResponseType.ACCEPT);

      get_content_area().add (ui_template);
      ui_template.list_templates.row_selected.connect ((row)=>{
        if (row == null)
          return;
        var entry = row as TemplateSelectorEntryTemplate;
        template = entry.template;
      });
      ui_template.ent_project_name.changed.connect (()=>{
        project_name = ui_template.ent_project_name.text;
      });
      ui_template.fch_dir.selection_changed.connect (()=>{
        directory = ui_template.fch_dir.get_filename();
      });
    }

  }

}
