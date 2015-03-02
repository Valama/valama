using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Data.glade")]
  private class EditorDataTemplate : Box {
  	[GtkChild]
  	public ListBox list_targets;
  	[GtkChild]
  	public ToolButton tb_add;
  	[GtkChild]
  	public ToolButton tb_remove;
  	[GtkChild]
  	public Entry ent_name;
  }

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Data_entry.glade")]
  private class EditorDataEntryTemplate : ListBoxRow {
    public EditorDataEntryTemplate (Project.DataTarget target) {
      lbl_file.label = target.file;
      ent_target.text = target.target;
      ent_target.changed.connect (()=>{
        target.target = ent_target.text;
      });
    }
  	[GtkChild]
  	public Label lbl_file;
  	[GtkChild]
  	public Entry ent_target;
  }


  public class EditorData : Editor {

    private EditorDataTemplate template = new EditorDataTemplate();

    public EditorData(Project.ProjectMemberData member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      title = "Resource";

      template.ent_name.text = member.name;
      template.ent_name.changed.connect (()=>{
        member.name = template.ent_name.text;
        member.project.member_data_changed (this, member);
      });

      template.tb_add.clicked.connect (()=>{
        string? selected_file = null;
        var file_chooser = new Gtk.FileChooserDialog ("Open File", null,
                                      Gtk.FileChooserAction.OPEN,
                                      Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                      Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
        if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
          var projectfolder = File.new_for_path (member.project.filename).get_parent();
          selected_file = projectfolder.get_relative_path (file_chooser.get_file());
        }
        file_chooser.destroy ();

        if (selected_file != null) {
          var new_data_target = new Project.DataTarget();
          new_data_target.file = selected_file;
          member.targets.add (new_data_target);
          update_list();
        }
      });
      template.tb_remove.clicked.connect (()=>{
        var selected_row = template.list_targets.get_selected_row();
        if (selected_row != null) {
          member.targets.remove (selected_row.get_data<Project.DataTarget>("target"));
          update_list ();
        }
      });

      update_list();
      widget = template;
    }
    private void update_list() {
      var my_member = member as Project.ProjectMemberData;
      foreach (Gtk.Widget widget in template.list_targets.get_children())
        template.list_targets.remove (widget);
      foreach (var target in my_member.targets) {
        var new_row = new EditorDataEntryTemplate (target);
        new_row.set_data<Project.DataTarget> ("target", target);
        template.list_targets.add (new_row);
      }
      template.list_targets.show_all();
    }
    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {

    }
    internal override void destroy_internal() {
    
    }
  }

}

