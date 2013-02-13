using GLib;
using Gtk;

static Label lbl_hello;

static void main (string[] args) {
    Gtk.init (ref args);

    var window_main = new Window();
    window_main.title = "Hello world!";
    window_main.set_default_size (200, 200);
    window_main.destroy.connect (Gtk.main_quit);

    var vbox_main = new Box (Orientation.VERTICAL, 0);

    lbl_hello = new Label ("Hello!");
    var btn_bye = new Button.with_label ("Magic!");

    btn_bye.clicked.connect (on_btn_bye_clicked);

    vbox_main.pack_start (lbl_hello, true, true);
    vbox_main.pack_start (btn_bye, false, true);

    window_main.add (vbox_main);

    window_main.show_all();

    Gtk.main();
}

static void on_btn_bye_clicked() {
    lbl_hello.label = "Bye!";
}
