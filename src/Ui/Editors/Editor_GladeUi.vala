using Gtk;

namespace Ui {

  public class EditorGladeUi : Editor {
  
    public Gtk.SourceView sourceview = new Gtk.SourceView ();
  
    private Project.ProjectMemberGladeUi my_member = null;


    private Glade.Project glade_project = new Glade.Project();
    private Glade.Inspector inspector = new Glade.Inspector();
    private Glade.DesignView design_view;
    private Glade.Palette palette = new Glade.Palette();
    private Glade.Editor editor = new Glade.Editor();
  
    public EditorGladeUi(Project.ProjectMemberGladeUi member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      my_member = member as Project.ProjectMemberGladeUi;
      title = member.getTitle();

      var grid = new Gtk.Grid();
      Glade.App.set_window (main_widget.window);

      glade_project = new Glade.Project();

      main_widget.main_toolbar.selected_target_changed.connect(hook_save_on_compile);
      hook_save_on_compile();

      // When content is changed, invalidate all targets depending on this file
      glade_project.changed.connect(()=>{
        foreach (var pmember in my_member.project.members) {
          if (pmember is Project.ProjectMemberTarget) {
            var target = pmember as Project.ProjectMemberTarget;
            if (target.included_gladeuis.contains (my_member.id))
              target.builder.state = Builder.BuilderState.NOT_COMPILED;
          }
        }
      });

      design_view = new Glade.DesignView (glade_project);
      glade_project.load_from_file (member.file.get_abs());
      Glade.App.add_project (glade_project);
      inspector.project = glade_project;
      palette.project = glade_project;

      inspector.selection_changed.connect (() => {
        var w = inspector.get_selected_items().nth_data (0);
        w.show();
        editor.widget = w;
      });
      inspector.item_activated.connect (() => {
        var w = inspector.get_selected_items().nth_data (0);
        w.show();
        editor.widget = w;
      });
      
      var paned_palette_design_view = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
      paned_palette_design_view.add1 (palette);
      var scrw = new ScrolledWindow(null, null);
      scrw.add (design_view);
      scrw.show();
      paned_palette_design_view.add2 (scrw);
      paned_palette_design_view.expand = true;
      palette.show();
      design_view.show();

      design_view.expand = true;
      grid.attach (paned_palette_design_view, 0, 0, 1, 2);
      grid.attach (inspector, 1, 0, 1, 1);
      grid.attach (editor, 1, 1, 1, 1);

      editor.show();
      grid.expand = true;

      widget = grid;
      widget.show_all();
    }

    // Before compiling, save file (if it is part of the selected target)
    ulong hook = 0;
    Builder.Builder hooked_builder = null;
    private void hook_save_on_compile() {
      if (hooked_builder != null) // track selected target
        hooked_builder.disconnect (hook);
      var builder = main_widget.main_toolbar.selected_target.builder;
      hook = builder.state_changed.connect (()=>{
        if (glade_project.modified)
          if (builder.state == Builder.BuilderState.COMPILING)
            if (main_widget.main_toolbar.selected_target.included_gladeuis.contains (my_member.id))
              glade_project.save (my_member.file.get_abs());
      });
      hooked_builder = builder;
    }

    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {
    }
    internal override void destroy_internal() {
      glade_project.save (my_member.file.get_abs());
      Glade.App.remove_project (glade_project);
    }
  }

}
