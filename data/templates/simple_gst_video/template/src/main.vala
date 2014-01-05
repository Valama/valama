using Gst;
using Gtk;

static void main (string[] args) {
    if (args.length < 2)
    {
		// Note: playbin handle uris, no paths.
        print ("usage: test file:///path/to/file\n");
        return;
    }
    
    Gtk.init (ref args);
    Gst.init (ref args);
    
    dynamic Element playbin = ElementFactory.make ("playbin", "playbin");
    playbin.uri = args[1];
    
    Window window = new Window();
    
    playbin.bus.add_watch (0, (bus, message) => {
		// get the window id of current GtkWindow for inlay the video.
        if (Gst.Video.is_video_overlay_prepare_window_handle_message (message))
            (message.src as Gst.Video.Overlay).set_window_handle ((uint*)Gdk.X11Window.get_xid (window.get_window()));
    
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
		// when the GtkWindow is shown, set the playbin state at PLAYING.
        playbin.set_state (State.PLAYING);
    });
    window.show_all();
    Gtk.main();
}
