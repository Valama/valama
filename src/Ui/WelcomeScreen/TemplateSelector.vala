using Gtk;

namespace Ui {
  public class TemplateBoxChild : Box {
    public TemplateBoxChild (ProjectTemplate template) {
      GLib.Object (template: template, orientation: Orientation.VERTICAL, spacing: 0);
    }

    construct {
      var lbl = new Label (template.name);
      Image img = null;
      if (template.icon_path != null)
        img = new Image.from_file (template.icon_path);
      else
        img = new Image.from_icon_name ("text-x-script", IconSize.DIALOG);

      pack_start (img, false, false);
      pack_start (lbl, false, false);
    }

    public ProjectTemplate template { get; construct; }
  }

  public class TemplateBox : Box {
    public TemplateBox (ProjectTemplateProvider provider) {
      GLib.Object (orientation: Orientation.VERTICAL, spacing: 0, provider: provider);
    }

    construct {
      Label lbl_author = new Label ("");
      Label lbl_description = new Label ("");
      pn_entry = new Entry();
      fch_dir = new FileChooserButton (_("Select folder"), FileChooserAction.SELECT_FOLDER);
      fch_dir.create_folders = true;
      FlowBox list_templates = new FlowBox();
      list_templates.activate_on_single_click = true;

      foreach (var template in provider.templates)
        list_templates.add (new TemplateBoxChild (template));

      list_templates.child_activated.connect (child => {
        var box_child = child.get_child() as TemplateBoxChild;
        lbl_author.label = box_child.template.author_name;
        lbl_description.label = box_child.template.description;
        child_activated (box_child);
      });

      pack_start (list_templates);
    }

    public signal void child_activated (TemplateBoxChild child);

    public ProjectTemplateProvider provider { get; construct; }
    public FlowBox list_templates { get; private set; }
    public Entry pn_entry { get; private set; }
    public FileChooserButton fch_dir { get; private set; }
  }

  public class TemplateSelector : Window {
    public ProjectTemplate? template = null;
    public string project_name = null;
    public string directory = null;

    public signal void response (ResponseType response_type);

    construct {
      var provider = new ProjectTemplateProvider();
      var selector = new TemplateBox (provider);

      var btn_cancel = new Button.from_icon_name ("dialog-cancel", IconSize.LARGE_TOOLBAR);
      btn_cancel.clicked.connect (() => {
        response (ResponseType.CANCEL);
      });
      var btn_open = new Button.from_icon_name ("dialog-ok", IconSize.LARGE_TOOLBAR);
      btn_open.clicked.connect (() => {
        response (ResponseType.ACCEPT);
      });

      var bar = new HeaderBar();
      bar.pack_start (btn_cancel);
      bar.pack_start (new Label (_("Project")));
      bar.pack_start (selector.pn_entry);
      bar.pack_end (btn_open);
      bar.pack_end (selector.fch_dir);
      bar.pack_end (new Label (_("Directory")));
      bar.title = _("Template Selector");
      bar.subtitle = _("Choose template for your project");
      set_titlebar (bar);

      add (selector);

      selector.child_activated.connect (child => {
        template = child.template;
      });
      selector.pn_entry.changed.connect (self => {
        project_name = (self as Entry).text;
      });
      selector.fch_dir.selection_changed.connect (self => {
        directory = self.get_filename();
      });
    }

    public int run() {
      int result = 0;
      var loop = new MainLoop();
      response.connect (rt => {
        result = rt;
        destroy();
        loop.quit();
      });
      show_all();
      loop.run();
      return result;
    }
  }
}
