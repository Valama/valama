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
  
    private FileTreeBox list_sources = new FileTreeBox();
    private FileTreeBox list_targets = new FileTreeBox();
    private FileTreeBox list_ui = new FileTreeBox();
    private FileTreeBox list_gresource = new FileTreeBox();
    private FileTreeBox list_data = new FileTreeBox();

    private ProjectStructureTemplate template = new ProjectStructureTemplate();
  
    // Maps project member types to corresponding list boxes
    private Gee.HashMap<Project.EnumProjectMember, FileTreeBox> mp_types_lists = new Gee.HashMap<Project.EnumProjectMember, FileTreeBox>();

    public override void init() {

      mp_types_lists[Project.EnumProjectMember.VALASOURCE] = list_sources;
      mp_types_lists[Project.EnumProjectMember.TARGET] = list_targets;
      mp_types_lists[Project.EnumProjectMember.GLADEUI] = list_ui;
      mp_types_lists[Project.EnumProjectMember.GRESOURCE] = list_gresource;
      mp_types_lists[Project.EnumProjectMember.DATA] = list_data;

      foreach (var type in mp_types_lists.keys)
        fill_list(type);

      foreach (var list in mp_types_lists.values)
        list.file_selected.connect(file_selected);

      // Select entry when editor is activated
      main_widget.editor_viewer.viewer_selected.connect ((viewer)=>{
        if (viewer is Editor) {
          var member = (viewer as Editor).member;
          mp_types_lists[member.get_project_member_type()].select (member.getTitle());
        }
      });

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
          if (listbox.selection_filename != null) {
            main_widget.project.removeMember (listbox.selection_data as Project.ProjectMember);
            listbox.remove_file (listbox.selection_filename);
            break;
          }
        }
      });


      template.algn_sources.add (list_sources.update());
      template.algn_targets.add (list_targets.update());
      template.algn_ui.add (list_ui.update());
      template.algn_gresource.add (list_gresource.update());
      template.algn_data.add (list_data.update());
      template.show_all();

      widget = template;
    }

    private void file_selected (string filename, Object data) {
      if (filename == null) {
        template.btn_remove.sensitive = false;
        return;
      }

      // Deactivate other lists
      foreach (var listbox in mp_types_lists.values)
        listbox.deselect (filename);

      // Open selected member
      main_widget.editor_viewer.openMember(data as Project.ProjectMember);
      
      template.btn_remove.sensitive = true;//member is Project.ProjectMemberValaSource || member is Project.ProjectMemberTarget;
    }
    
    private void fill_list(Project.EnumProjectMember type) {
      
      FileTreeBox box = mp_types_lists[type];
      
      // Fill with project members of right type
      foreach (Project.ProjectMember member in main_widget.project.members) {
        if (member.get_project_member_type() != type)
          continue;
        box.add_file (member.getTitle(), member);
      }
    }
    
    public override void destroy() {
    
    }
  }

}
