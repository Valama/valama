static int main (string[] args) {

  var project = new Project.Project();
  project.load ("valama.vlp");

  GtkClutter.init (ref args);
  
  var main_widget = new Ui.MainWidget(project);

  var window = new Gtk.Window ();
  window.set_default_size (600, 500);
  window.add (main_widget.widget);


  window.destroy.connect(()=>{
    main_widget.destroy();
    Gtk.main_quit();
  });

  window.show();
  Gtk.main();
  

  project.save ();
  
  return 0;
}
