void main (string[] args)
{
	if (args.length < 2)
	{
		print ("usage: main file://path/to/file or main http://radio:8080");
		return;
	}
	Gst.init (ref args);
	var loop = new MainLoop();
	dynamic Gst.Element playbin = Gst.ElementFactory.make ("playbin","playbin");
	playbin.bus.add_watch (0, (bus, message) => {
		switch (message.type)
		{
			case Gst.MessageType.ERROR:
				print ("error occured !");
				loop.quit();
			break;
			case Gst.MessageType.EOS:
				loop.quit();
			break;
		}
		return false;
	});
	playbin.uri = args[1];
	playbin.set_state (Gst.State.PLAYING);
	loop.run();
}
