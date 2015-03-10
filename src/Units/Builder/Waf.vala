namespace Builder {
    public class Waf : Builder {
        private string waf_executable = "./waf"
        private string build_dir = "build/" + target.binary_name + "/waf/";
        
        private string configure_command = waf_executable+" configure --out="+build_dir;
        private string build_command = waf_executable+" build";
        private string run_command = waf_executable+" run";
        private string clean_command = waf_executable+" distclean";
    
        public override Gtk.Widget? init_ui() {
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
        public override void build(Ui.MainWidget main_widget) {
            
        }
        public override void run(Ui.MainWidget main_widget) {
            
        }
        public override void abort_run() {
            
        }
        public override void clean() {
            
        }
    }
}
