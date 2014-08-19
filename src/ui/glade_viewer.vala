using Gtk;
using Glade;
using Gdl;

public class GladeViewer : UiElement
{
	Box vbox;
	
	Project glade_project;
	Inspector inspector;
	DesignView design_view;
	Palette palette;
	Editor editor;
	SignalEditor signals;
	DockItem dv_item;
	string project_path;
	
	public GladeViewer()
	{
		vbox = new Box (Orientation.VERTICAL, 0);
		App.set_window (vbox);
		glade_project = new Project();
		App.add_project (glade_project);
		inspector = new Inspector();
		palette = new Palette();
		editor = new Editor();
		signals = new SignalEditor();
		inspector.selection_changed.connect (() => {
			var w = inspector.get_selected_items().nth_data (0);
			w.show();
			editor.load_widget (w);
		});
        inspector.item_activated.connect (() => {
			var w = inspector.get_selected_items().nth_data (0);
			w.show();
			editor.load_widget (w);
			signals.load_widget (w);
		});
		var dock = new Dock();
        var bar = new DockBar (dock);
        var toolbar = new Toolbar ();
        toolbar.get_style_context().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
        var btn_save = new ToolButton (null, null);
        btn_save.icon_name = "document-save";
        btn_save.tooltip_text = "save this UI";
        btn_save.clicked.connect (() => {
			try {
				glade_project.save (project_path);
			} catch {
			
			}
		});
		toolbar.add (btn_save);
        vbox.pack_start (toolbar, false, true, 0);
        var box = new Box (Orientation.HORIZONTAL, 0);
        box.pack_start (bar, false, false, 0);
        box.pack_end (dock, true, true, 0);
        vbox.pack_start (box);
        var item1 = new DockItem ("palette", "Palette", DockItemBehavior.NORMAL);
        var item2 = new DockItem ("editor", "Editor", DockItemBehavior.NORMAL);
        dv_item = new DockItem ("designview", "Design View", DockItemBehavior.NORMAL);
        var item4 = new DockItem.with_stock ("inspector", "Inspector", "gtk-find", DockItemBehavior.NORMAL);
        var item5 = new DockItem.with_stock ("Signals", "Signals", "gtk-find", DockItemBehavior.NORMAL);
        item1.add (palette);
        item2.add (editor);
        item4.add (inspector);
        item5.add (signals);
        dock.add_item (item1, DockPlacement.TOP);
        dock.add_item (item2, DockPlacement.BOTTOM);
        dock.add_item (dv_item, DockPlacement.RIGHT);
        dock.add_item (item4, DockPlacement.LEFT);
        dock.add_item (item5, DockPlacement.LEFT);
        dv_item.dock_to (item1, DockPlacement.TOP, -1);
        item1.show();
        item2.show();
        item4.show();
        item5.show();
        palette.show();
        editor.show();
        inspector.show();
        signals.show();
		project.guanako_update_finished.connect (build);
		widget = vbox;
	}
	
	public void load (string path)
	{
		if (glade_project != null)
			App.remove_project (glade_project);
		project_path = path;
		glade_project = Project.load (path);
		App.add_project (glade_project);
		inspector.project = glade_project;
		palette.project = glade_project;
		design_view = new DesignView (glade_project);
        dv_item.set_child (design_view);
        dv_item.show();
		design_view.show();
		vbox.show_all();
	}
	
	protected override void build ()
	{
		
	}
}
