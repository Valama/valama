using Gtk;
using Vala;
using GLib;

static Window window_main;

static Guanako.project project;
static SourceView view;
static SourceFile main_file;

public static void main(string[] args){
	Gtk.init(ref args);
	
	string sourcedir = Environment.get_current_dir();
	
	project = new Guanako.project();

	project.add_package ("gobject-2.0");
	project.add_package ("glib-2.0");
	project.add_package ("gio-2.0");
	project.add_package ("gee-1.0");
	project.add_package ("libvala-0.16");
	project.add_package ("gdk-3.0");
	project.add_package ("gtk+-3.0");
	project.add_package ("gtksourceview-3.0");
	
	/*project.add_package ("gobject-2.0");
	project.add_package ("glib-2.0");
	project.add_package ("gio-2.0");
	project.add_package ("libxml-2.0");
	project.add_package ("gee-1.0");
	project.add_package ("gmodule-2.0");
	project.add_package ("gdk-3.0");
	project.add_package ("gtk+-3.0");
	project.add_package ("clutter-1.0");
	project.add_package ("clutter-gtk-1.0");*/
	

	var directory = File.new_for_path (sourcedir);

    var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

    main_file = null;

    FileInfo file_info;
    while ((file_info = enumerator.next_file ()) != null) {
        string file = sourcedir + "/" + file_info.get_name ();
        if (file.has_suffix(".vala")){
	        stdout.printf(@"Found file $file\n");
		    var source_file = new SourceFile (project.code_context, SourceFileType.SOURCE, file);
			project.add_source_file (source_file);

            if (file.has_suffix("main.vala"))
                main_file = source_file;
	    }
    }

	project.update();



	
	window_main = new Window();
	
	
	
	view = new SourceView();
	view.show_line_numbers = true;
	var bfr = (SourceBuffer)view.buffer;
	bfr.set_highlight_syntax(true);

	TestProvider tp = new TestProvider ();
	tp.priority = 1;
	tp.name = "Test Provider 1";

	view.completion.add_provider (tp);
	
    view.buffer.changed.connect(on_view_buffer_changed);
	
	var langman = new SourceLanguageManager();
	var lang = langman.get_language("vala");
	bfr.set_language(lang);

	string txt = "";
	FileUtils.get_contents(sourcedir + "/main.vala", out txt);
	bfr.text = txt;
	

    var hbox = new HBox(false, 0);

	var scrw = new ScrolledWindow(null, null);
	scrw.add(view);
    hbox.pack_start(scrw, true, true);
	
	var scrw2 = new ScrolledWindow(null, null);
	var brw = new symbol_browser(project);
	scrw2.add(brw.widget);
    hbox.pack_start(scrw2, true, true);

	window_main.add(hbox);
	
	window_main.set_default_size(700, 600);
	window_main.destroy.connect(Gtk.main_quit);
	window_main.show_all();
	
	Gtk.main();
}

static void on_view_buffer_changed(){
}

class TestProvider : Gtk.SourceCompletionProvider, Object
{
  Gdk.Pixbuf icon;
  public string name;
  public int priority;
  GLib.List<Gtk.SourceCompletionItem> proposals;

  construct
  {
	  Gdk.Pixbuf icon = this.get_icon ();

    this.proposals = new GLib.List<Gtk.SourceCompletionItem> ();
	  this.proposals.prepend (new Gtk.SourceCompletionItem ("Proposal 3", "Proposal 3", null, null));
	  this.proposals.prepend (new Gtk.SourceCompletionItem ("Proposal 2", "Proposal 2", null, null));
	  this.proposals.prepend (new Gtk.SourceCompletionItem ("Proposal 1", "Proposal 1", null, null));
  }

  public string get_name ()
  {
	  return this.name;
  }

  public int get_priority ()
  {
	  return this.priority;
  }

  public bool match (Gtk.SourceCompletionContext context)
  {
	  return true;
  }

  public void populate (Gtk.SourceCompletionContext context)
  {
  	var props = new GLib.List<Gtk.SourceCompletionItem> ();
  	
	var mark = view.buffer.get_insert();
	TextIter iter;
	view.buffer.get_iter_at_mark(out iter, mark);
	var line = iter.get_line() + 1;
	var col = iter.get_line_offset();
	
	TextIter iter_start;
	view.buffer.get_iter_at_line(out iter_start, line - 1);
	var current_line = view.buffer.get_text(iter_start, iter, false);
	
	string[] splt = current_line.split_set(" .");
	string last = "";
	if (splt.length > 0)
	    last = splt[splt.length - 1];
	
	var proposals = project.propose_symbols(main_file, line, col, current_line);
	foreach (Symbol proposal in proposals){
		if (proposal.name != null){
		    if (proposal.name.has_prefix(last))
    			props.prepend(new Gtk.SourceCompletionItem (proposal.name, proposal.name, null, null));
		}
	}
	
	context.add_proposals (this, props, true);
  }

  public weak Gdk.Pixbuf? get_icon ()
  {
	  if (this.icon == null)
	  {
		  Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
		  this.icon = theme.load_icon (Gtk.STOCK_DIALOG_INFO, 16, 0);
	  }
  	return this.icon;
  }

  public bool activate_proposal (Gtk.SourceCompletionProposal proposal,
                                 Gtk.TextIter iter)
  {
    return true;
  }

  public Gtk.SourceCompletionActivation get_activation ()
  {
    return Gtk.SourceCompletionActivation.INTERACTIVE |
	          Gtk.SourceCompletionActivation.USER_REQUESTED;
  }

  public unowned Gtk.Widget? get_info_widget (Gtk.SourceCompletionProposal proposal)
  {
    return null;
  }

  public int get_interactive_delay ()
  {
    return -1;
  }

  public bool get_start_iter (Gtk.SourceCompletionContext context,
                              Gtk.SourceCompletionProposal proposal,
                              Gtk.TextIter iter)
  {
    return false;
  }

  public void update_info (Gtk.SourceCompletionProposal proposal, 
                           Gtk.SourceCompletionInfo info)
  {
  }
}
