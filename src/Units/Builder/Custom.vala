using Gtk;

namespace Builder {

  [GtkTemplate (ui = "/src/Units/Builder/Custom.glade")]
  private class CustomTemplate : Grid {
  	[GtkChild]
  	public Entry ent_build_command;
  	[GtkChild]
  	public Entry ent_run_command;
  	[GtkChild]
  	public Entry ent_clean_command;
  }

  public class Custom : Builder {
  
    private string build_command = "";
    private string run_command = "";
    private string clean_command = "";
  
    public override Gtk.Widget? init_ui() {
      // Keep command entries in sync
      var template = new CustomTemplate();
      template.ent_build_command.text = build_command;
      template.ent_build_command.changed.connect (()=>{
        build_command = template.ent_build_command.text;
      });
      template.ent_run_command.text = run_command;
      template.ent_run_command.changed.connect (()=>{
        run_command = template.ent_run_command.text;
      });
      template.ent_clean_command.text = clean_command;
      template.ent_clean_command.changed.connect (()=>{
        clean_command = template.ent_clean_command.text;
      });
      return template;
    }
    public override void load (Xml.Node* node) {
      for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
        if (prop->name == "build_command")
          build_command = prop->children->content;
        else if (prop->name == "run_command")
          run_command = prop->children->content;
        else if (prop->name == "clean_command")
          clean_command = prop->children->content;
      }
    }
    public override void save (Xml.TextWriter writer) {
      writer.write_attribute ("build_command", build_command);
      writer.write_attribute ("run_command", run_command);
      writer.write_attribute ("clean_command", clean_command);
    }
    private ulong process_exited_handler;
    public override void build(Ui.MainWidget main_widget) {
      Pid child_pid = main_widget.console_view.spawn_process (build_command);

      state = BuilderState.COMPILING;

      process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
        state = BuilderState.COMPILED_OK;
        main_widget.console_view.disconnect (process_exited_handler);
      });
    }
    Pid run_pid;
    public override void run(Ui.MainWidget main_widget) {
      run_pid = main_widget.console_view.spawn_process (run_command);

      state = BuilderState.RUNNING;

      process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
        state = BuilderState.COMPILED_OK;
        main_widget.console_view.disconnect (process_exited_handler);
      });
    }
    public override void abort_run() {
      Posix.kill (run_pid, 15);
      Process.close_pid (run_pid);
    }
    public override void clean() {
    
    }

  }
}
