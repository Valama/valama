using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/ProjectStructure.glade")]
  private class ProjectStructureTemplate : Box {
  	[GtkChild]
  	public Alignment algn_sources;
  	[GtkChild]
  	public Alignment algn_targets;
  	[GtkChild]
  	public Alignment algn_ui;
  	[GtkChild]
  	public Alignment algn_data;
  	[GtkChild]
  	public Alignment algn_gresource;
  	[GtkChild]
  	public ToolButton btn_add;
  	[GtkChild]
  	public ToolButton btn_remove;
  }

  [GtkTemplate (ui = "/src/Ui/NewProjectMember.glade")]
  private class NewMemberDialogTemplate : ListBox {
  	[GtkChild]
  	public ListBoxRow row_new_source;
  	[GtkChild]
  	public ListBoxRow row_open_source;
  	[GtkChild]
  	public ListBoxRow row_new_target;
  	[GtkChild]
  	public ListBoxRow row_open_gladeui;
  	[GtkChild]
  	public ListBoxRow row_new_gresource;
  	[GtkChild]
  	public ListBoxRow row_new_data;
  }

  public class ProjectStructure : Element {
  
    private Gtk.ListBox list_sources = new Gtk.ListBox();
    private Gtk.ListBox list_targets = new Gtk.ListBox();
    private Gtk.ListBox list_ui = new Gtk.ListBox();
    private Gtk.ListBox list_gresource = new Gtk.ListBox();
    private Gtk.ListBox list_data = new Gtk.ListBox();

    private ProjectStructureTemplate template = new ProjectStructureTemplate();
  
    // Maps project member types to corresponding list boxes
    private Gee.HashMap<Project.EnumProjectMember, Gtk.ListBox> mp_types_lists = new Gee.HashMap<Project.EnumProjectMember, Gtk.ListBox>();

    public override void init() {

      mp_types_lists[Project.EnumProjectMember.VALASOURCE] = list_sources;
      mp_types_lists[Project.EnumProjectMember.TARGET] = list_targets;
      mp_types_lists[Project.EnumProjectMember.GLADEUI] = list_ui;
      mp_types_lists[Project.EnumProjectMember.GRESOURCE] = list_gresource;
      mp_types_lists[Project.EnumProjectMember.DATA] = list_data;

      foreach (var type in mp_types_lists.keys)
        fill_list(type);

      foreach (var list in mp_types_lists.values)
        list.row_selected.connect(row_selected);

      // Keep lists up to date
      main_widget.project.member_added.connect((member)=>{
        fill_list(member.get_project_member_type());
      });
      main_widget.project.member_removed.connect((member)=>{
        fill_list(member.get_project_member_type());
      });


      // Add new element to project
      template.btn_add.clicked.connect (() => {
        var dlg_template = new NewMemberDialogTemplate();
        var new_member_dialog = new Dialog.with_buttons("", main_widget.window, DialogFlags.MODAL, _("OK"), ResponseType.OK, _("Cancel"), ResponseType.CANCEL);
        new_member_dialog.get_content_area().add (dlg_template);
        var ret = new_member_dialog.run();
        if (ret == ResponseType.OK) {
          if (dlg_template.get_selected_row() == dlg_template.row_open_source)
            main_widget.project.createMember (Project.EnumProjectMember.VALASOURCE);
          else if (dlg_template.get_selected_row() == dlg_template.row_new_target)
            main_widget.project.createMember (Project.EnumProjectMember.TARGET);
          else if (dlg_template.get_selected_row() == dlg_template.row_open_gladeui)
            main_widget.project.createMember (Project.EnumProjectMember.GLADEUI);
          else if (dlg_template.get_selected_row() == dlg_template.row_new_gresource)
            main_widget.project.createMember (Project.EnumProjectMember.GRESOURCE);
          else if (dlg_template.get_selected_row() == dlg_template.row_new_data)
            main_widget.project.createMember (Project.EnumProjectMember.DATA);
        }
        new_member_dialog.destroy();
      });
      
      // Remove selected element
      template.btn_remove.clicked.connect (() => {
        // Find active list
        foreach (var listbox in mp_types_lists.values) {
          var selected_row = listbox.get_selected_row();
          if (selected_row != null) {
            main_widget.project.removeMember (selected_row.get_data<Project.ProjectMember>("member"));
            break;
          }
        }
      });
      
      
      template.algn_sources.add (list_sources);
      template.algn_targets.add (list_targets);
      template.algn_ui.add (list_ui);
      template.algn_gresource.add (list_gresource);
      template.algn_data.add (list_data);
      template.show_all();
      
      widget = template;
    }
    
    private void row_selected (Gtk.ListBoxRow? row) {
      if (row == null) {
        template.btn_remove.sensitive = false;
        return;
      }

      // Deactivate other lists
      foreach (var listbox in mp_types_lists.values)
        if (listbox != row.parent)
          listbox.select_row (null);

      // Open selected member
      var member = row.get_data<Project.ProjectMember>("member");
      main_widget.editor_viewer.openMember(member);
      
      template.btn_remove.sensitive = true;//member is Project.ProjectMemberValaSource || member is Project.ProjectMemberTarget;
    }
    
    private void fill_list(Project.EnumProjectMember type) {
      
      Gtk.ListBox list = mp_types_lists[type];
      
      // Clear list
      foreach (Gtk.Widget widget in list.get_children())
        list.remove (widget);
        
      // Fill with project members of right type
      foreach (Project.ProjectMember member in main_widget.project.members) {
        if (member.get_project_member_type() != type)
          continue;
        var row = new Gtk.ListBoxRow();
        var label = new Gtk.Label(member.getTitle());

        // Keep label up to date
        member.project.member_data_changed.connect((sender, mb)=>{
          if (mb == member)
            label.label = member.getTitle();
        });

        row.add (label);
        row.set_data<Project.ProjectMember> ("member", member);
        list.add (row);
      }
      list.show_all();
    }
    
    public override void destroy() {
    
    }
  }

}
