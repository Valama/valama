using Gtk;

public static int main (string [] args){
    Gtk.init (ref args);
    var hello = new Hello.Hello ();
    return hello.run (args);
}

namespace Hello{
public class Hello : Granite.Application{
    
    public Window main_window;
    
    construct{
   	 program_name = "Hello"; //the name of your program
   	 exec_name = "Hello";	//the name of the executable, usually the name in lower case
   	 
   	 /*
   	 //those will be defined in a separate constants file, don't care about them here
   	 build_data_dir = Constants.DATADIR;
   	 build_pkg_data_dir = Constants.PKGDATADIR;
   	 build_release_name = Constants.RELEASE_NAME;
   	 build_version = Constants.VERSION;
   	 build_version_info = Constants.VERSION_INFO;
   	 */
   	 
   	 app_years = "2013";
   	 app_icon = "hello";  //the icon for your app. you normally ship it with your project in the data directory and copy it to the icon directory. You don't include file endings here (you can also use one of the default icons as I'm doing here)
   	 app_launcher = "hello.desktop";  //the .desktop file for your app, also in data directory
   	 application_id = "org.elementary.hello";  //an unique id which will identify your application
   	 
   	 //those urls will be shown in the automatically generated about dialog
   	 main_url = "";
   	 bug_url = "";
   	 help_url = "";
   	 translate_url = "";
   	 
   	 //here you can proudly list your own name and the names of those who helped you
   	 about_authors = {""};
   	 about_documenters = {"Mario Marcec <mario.marce42@googlmail.com>"};
   	 about_artists = {"Mario Marcec"};  //if you got an icon or a nice mockup from someone you can list him here
   	 about_comments = "A simple Hello to you";  //a short comment on the app
   	 about_translators = "";
   	 about_license_type = License.GPL_3_0;  //this should be one of http://unstable.valadoc.org/#!api=gtk+-3.0/Gtk.License; For elementary GPL3 is the default one, it’s a good idea to use it
    }
    
    public Hello (){
   	 //this.set_flags (ApplicationFlags.HANDLES_OPEN);
   	 Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
    }
    
    public override void activate (){
	if (this.main_window == null)
   	 	build_and_run ();
    }
    public void build_and_run (){
     this.main_window = new Window ();
     this.main_window.set_default_size (640, 480);
     this.main_window.set_application (this);
     this.main_window.window_position = WindowPosition.CENTER;
    var pop =  new Granite.Widgets.PopOver();
    var button = new Button.with_label ("Click me!");
    button.clicked.connect (() => {
        button.label = "Thank you";
    });
    pop.move_to_widget(button);

    this.main_window.add(button);
    this.main_window.show_all ();
    }

}

}
