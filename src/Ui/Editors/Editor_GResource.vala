using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_GResource.glade")]
  private class EditorGResourceTemplate : Box {
  	[GtkChild]
  	public ListBox list_files;
  	[GtkChild]
  	public ToolButton tb_add;
  	[GtkChild]
  	public ToolButton tb_remove;
  	[GtkChild]
  	public Entry ent_name;
  }

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_GResource_entry.glade")]
  private class EditorGResourceEntryTemplate : ListBoxRow {
    public EditorGResourceEntryTemplate (Project.GResource resource) {
      lbl_file.label = resource.file.get_rel();
      chk_compressed.active = resource.compressed;
      chk_compressed.toggled.connect (()=>{
        resource.compressed = chk_compressed.active;
      });
      chk_xml_stripblanks.active = resource.xml_stripblanks;
      chk_xml_stripblanks.toggled.connect (()=>{
        resource.xml_stripblanks = chk_xml_stripblanks.active;
      });
    }
    [GtkChild]
    public CheckButton chk_xml_stripblanks;
    [GtkChild]
    public CheckButton chk_compressed;
    [GtkChild]
    public Label lbl_file;
  }


  public class EditorGResource : Editor {

    private EditorGResourceTemplate template = new EditorGResourceTemplate();

    public EditorGResource(Project.ProjectMemberGResource member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      title = "Resource";
      
      template.ent_name.text = member.name;
      template.ent_name.changed.connect (()=>{
        member.name = template.ent_name.text;
        member.project.member_data_changed (this, member);
      });
      
      template.tb_add.clicked.connect (()=>{
        var file_chooser = new Gtk.FileChooserDialog ("Open File", null,
                                      Gtk.FileChooserAction.OPEN,
                                      Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                      Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
        if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
          var new_res = new Project.GResource();
          new_res.file = new Project.FileRef.from_file (main_widget.project, file_chooser.get_file());
          member.resources.add (new_res);
          update_list();
        }
        file_chooser.destroy ();
      });
      template.tb_remove.clicked.connect (()=>{
        var selected_row = template.list_files.get_selected_row();
        if (selected_row != null) {
          member.resources.remove (selected_row.get_data<Project.GResource>("resource"));
          update_list ();
        }
      });

      update_list();
      widget = template;
    }
    private void update_list() {
      var my_member = member as Project.ProjectMemberGResource;
      foreach (Gtk.Widget widget in template.list_files.get_children())
        template.list_files.remove (widget);
      foreach (var resource in my_member.resources) {
        var new_row = new EditorGResourceEntryTemplate (resource);
        new_row.set_data<Project.GResource> ("resource", resource);
        template.list_files.add (new_row);
      }
      template.list_files.show_all();
    }
    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {

    }
    internal override void destroy_internal() {
    
    }
  }

}

