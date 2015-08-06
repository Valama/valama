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

      // Keep lists up to date
      main_widget.project.member_added.connect((member)=>{
        fill_list(member.get_project_member_type());
      });

      // Popover for adding project members
      var popover = new Popover (template.btn_add);
      var dlg_template = new NewMemberDialogTemplate();
      popover.add (dlg_template);
      dlg_template.show_all();
      template.btn_add.clicked.connect (() => {
        popover.show();
      });

      dlg_template.row_activated.connect ((row)=>{
        popover.hide();

        Project.ProjectMember? member = null;
        if (row == dlg_template.row_open_source)
          member = Ui.ProjectMemberCreator.createValaSourceOpen (main_widget.project);
        else if (row == dlg_template.row_new_source)
          member = Ui.ProjectMemberCreator.createValaSourceNew (main_widget.project);
        else if (row == dlg_template.row_new_target)
          member = Ui.ProjectMemberCreator.createTarget (main_widget.project);
        else if (row == dlg_template.row_open_gladeui)
          member = Ui.ProjectMemberCreator.createGladeUi (main_widget.project);
        else if (row == dlg_template.row_new_gresource)
          member = Ui.ProjectMemberCreator.createGResource (main_widget.project);
        else if (row == dlg_template.row_new_data)
          member = Ui.ProjectMemberCreator.createData (main_widget.project);

        if (member != null)
          main_widget.project.addNewMember (member);
      });


      // Remove selected element
      template.btn_remove.clicked.connect (() => {
        // Find active list
        foreach (var listbox in mp_types_lists.values) {
          if (listbox.selection != null) {
            var remove_file = listbox.selection;
            listbox.remove_file (remove_file);
            main_widget.project.removeMember (remove_file.data as Project.ProjectMember);
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

      // Select entry when editor is activated
      var viewer = main_widget.editor_viewer.getSelectedViewer();
      if (viewer is Editor) {
        var member = (viewer as Editor).member;
        var list = mp_types_lists[member.get_project_member_type()];
        list.select (list.get_entry(member.getTitle()));
      }
      main_widget.editor_viewer.viewer_selected.connect ((viewer)=>{
        if (viewer is Editor) {
          var member = (viewer as Editor).member;
          var list = mp_types_lists[member.get_project_member_type()];
          list.select (list.get_entry(member.getTitle()));
        }
      });

      widget = template;
    }

    private void file_selected (FileTreeBox.FileEntry entry) {
      if (entry == null) {
        template.btn_remove.sensitive = false;
        return;
      }

      var member = entry.data as Project.ProjectMember;

      // Deactivate other lists
      foreach (var listbox in mp_types_lists.values)
        if (listbox != mp_types_lists[member.get_project_member_type()])
          listbox.deselect ();

      // Open selected member
      main_widget.editor_viewer.openMember(member);
      
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
