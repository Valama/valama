using Gtk;
using Vte;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/ConsoleView.glade")]
  private class ConsoleViewTemplate : Box {
  	[GtkChild]
  	public Viewport vwp_console;
  }

  public class ConsoleView : Element {

    private ConsoleViewTemplate template = new ConsoleViewTemplate();
    private Terminal terminal = new Terminal();
    public override void init() {
      template.vwp_console.add(terminal);
      terminal.show();

      widget = template;
      terminal.child_exited.connect (()=>{
        process_exited();
      });
    }

    public signal void process_exited();

    public Pid spawn_process (string command) {

      // Clear terminal
      terminal.reset(true, true);

      // Get argument vector from command
      string[] argv;
      Shell.parse_argv (command, out argv);
      Pid child_pid;
      // Spawn the process
#if VTE_2_91
      Process.spawn_async (null, argv, null, SpawnFlags.DO_NOT_REAP_CHILD, null, out child_pid);
      terminal.watch_child (child_pid);
#else
      terminal.fork_command_full (PtyFlags.DEFAULT, null, argv, null, SpawnFlags.DO_NOT_REAP_CHILD, null, out child_pid);
#endif
      return child_pid;
    }

    public override void destroy() {
      
    }
  }

}
