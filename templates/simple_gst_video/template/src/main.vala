using Gst;
using Gtk;

static void main (string[] args) {
    if (args.length < 2)
    {
		// Note: playbin handle uris, no paths.
        print ("usage: test file:///path/to/file\n");
        return;
    }
    
    // Init libraries
    X.init_threads();
    Gtk.init (ref args);
    Gst.init (ref args);
    
    dynamic Element playbin = ElementFactory.make ("playbin", "playbin");
    Element sink = ElementFactory.make ("glimagesink", "sink");
    playbin.video_sink = sink;
    playbin.uri = args[1];
    
    Window window = new Window();
    
    playbin.bus.add_watch (0, (bus, message) => {
        switch (message.type)
        {
            case Gst.MessageType.ERROR:
                print ("an error was occured !\n");
                Gtk.main_quit();
                break;
            case Gst.MessageType.EOS:
                print ("end of current stream. quit ..\n");
                Gtk.main_quit();
                break;
        }
        return true;
    });
    
    window.realize.connect(() => {
		(sink as Gst.Video.Overlay).set_window_handle ((uint*)((Gdk.X11.Window)window.get_window()).get_xid());
		// when the GtkWindow is shown, set the playbin state at PLAYING.
        playbin.set_state (State.PLAYING);
    });
    window.show_all();
    Gtk.main();
}
