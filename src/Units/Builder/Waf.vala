namespace Builder {

    public class Waf : Builder {
    
        private string waf_executable = "./waf";
        
        private string configure_command = " configure --out=";
        private string build_command = " build";
        private string run_command = " run";
        private string clean_command = " distclean"; // also clean possible, but then without removing configure files
        
        private ulong process_exited_handler;
        Pid run_pid;
        Ui.MainWidget main_widget;
    
        public Waf () {
            // check waf executable location
            // ... TODO: code here ...
            
            // set build path
            build_dir = "build/" + target.binary_name + "/waf/";
            configure_command += build_dir;
            
            // set waf commands
            configure_command   = waf_executable + configure_command;
            build_command       = waf_executable + build_command;
            run_command         = waf_executable + run_command;
            clean_command       = waf_executable + clean_command;
        }
    
        public override Gtk.Widget? init_ui() {
            // TODO: template to configurate commands
            return null;
        }
        public override void load (Xml.Node* node) {
            
        }
        public override void save (Xml.TextWriter writer) {
          writer.write_attribute ("build_command", build_command);
          writer.write_attribute ("run_command", run_command);
          writer.write_attribute ("clean_command", clean_command);
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
            run_pid = main_widget.console_view.spawn_process (build_dir + target.binary_name);
            
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
