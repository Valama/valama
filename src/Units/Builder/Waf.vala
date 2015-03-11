using Gtk;

namespace Builder {

    [GtkTemplate (ui = "/src/Units/Builder/Waf.glade")]
    private class WafTemplate : Grid {
        [GtkChild]
        public Entry ent_waf_command;
        [GtkChild]
        public Entry ent_configure_command;
        [GtkChild]
        public Entry ent_build_command;
        [GtkChild]
        public Entry ent_run_command;
        [GtkChild]
        public Entry ent_clean_command;
    }

    public class Waf : Builder {
    
        private string waf_command;
        
        private string configure_command;
        private string build_command;
        private string run_command;
        private string clean_command; // also clean possible, but then without removing configure files
        
        private ulong process_exited_handler;
        Pid run_pid;
        Ui.MainWidget main_widget;
    
        public override Gtk.Widget? init_ui() {
            // Keep command entries in sync
            var template = new WafTemplate();

            template.ent_waf_command.text = waf_command;
            template.ent_waf_command.changed.connect (()=>{
                waf_command = template.ent_waf_command.text;
            });
            template.ent_configure_command.text = configure_command;
            template.ent_configure_command.changed.connect (()=>{
                configure_command = template.ent_configure_command.text;
            });
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

        public override void set_defaults() {
          waf_command = "./waf";
          configure_command = " configure --out=";
          build_command = " build";
          run_command = " run";
          clean_command = " distclean";
        }

        public override void load (Xml.Node* node) {
          // check waf executable location
          // ... TODO: code here ...

          // set build path
          build_dir = "build/" + target.binary_name + "/waf/";
          configure_command += build_dir;

          for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
            if (prop->name == "build_command")
                build_command = prop->children->content;
            else if (prop->name == "run_command")
                run_command = prop->children->content;
            else if (prop->name == "clean_command")
                clean_command = prop->children->content;
            else if (prop->name == "configure_command")
                configure_command = prop->children->content;
            else if (prop->name == "waf_command")
                waf_command = prop->children->content;
          }
        }
        public override void save (Xml.TextWriter writer) {
          writer.write_attribute ("build_command", build_command);
          writer.write_attribute ("run_command", run_command);
          writer.write_attribute ("clean_command", clean_command);
          writer.write_attribute ("configure_command", configure_command);
          writer.write_attribute ("waf_command", waf_command);
        }
        public override bool can_export () {
            return false;
        }
        public override void export (Ui.MainWidget main_widget) {
            
        }
        public override void build (Ui.MainWidget main_widget) {
            Pid child_pid = main_widget.console_view.spawn_process (build_command);
            this.main_widget = main_widget;

            state = BuilderState.COMPILING;

            process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
                state = BuilderState.COMPILED_OK;
                main_widget.console_view.disconnect (process_exited_handler);
            });
        }
        public override void run (Ui.MainWidget main_widget) {
            run_pid = main_widget.console_view.spawn_process (run_command);
            
            state = BuilderState.RUNNING;

            process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
                state = BuilderState.COMPILED_OK;
                main_widget.console_view.disconnect (process_exited_handler);
            });
        }
        public override void abort_run () {
            Posix.kill (run_pid, 15);
            Process.close_pid (run_pid);
        }
        public override void clean () {
            Pid child_pid = main_widget.console_view.spawn_process (clean_command);

            state = BuilderState.NOT_COMPILED;

            process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
                state = BuilderState.NOT_COMPILED;
                main_widget.console_view.disconnect (process_exited_handler);
            });
        }
        
    }
}
