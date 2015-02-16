static int main (string[] args) {

  GtkClutter.init (ref args);
  
  var window = new Gtk.Window ();
  window.set_default_size (600, 500);

  Ui.MainWidget main_widget = null;

  if (args.length > 1) {

    var project = new Project.Project();
    project.load (args[1]);
    main_widget = new Ui.MainWidget(project, window);
    window.add (main_widget.widget);

  } else {

    var welcome_screen = new Ui.WelcomeScreen();
    window.add (welcome_screen.widget);

    welcome_screen.project_selected.connect ((project)=>{
      main_widget = new Ui.MainWidget(project, window);
      welcome_screen.widget.destroy();
      window.add (main_widget.widget);
    });

  }

  window.destroy.connect(()=>{
    if (main_widget != null)
      main_widget.destroy();
    Gtk.main_quit();
  });

  window.show();
  Gtk.main();

  return 0;
}
