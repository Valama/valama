using Vala;

namespace Units {

  public class IconProvider : Unit {

    private Gee.HashMap<string, Gdk.Pixbuf> map_icons = new Gee.HashMap<string, Gdk.Pixbuf>();

    public override void init() {

      string pixmap_path = Config.DATA_DIR + "/share/valama/pixmaps";
      var imagedir = File.new_for_path (pixmap_path);

      if (!imagedir.query_exists()) {
          stderr.printf (_("Pixmap directory does not exist. No application icons can be used.\n"));
          return;
      }
      var type_regex = /^element-[a-zA-Z_-]+-16\.png$/;

      try {
          var enumerator = imagedir.enumerate_children ("standard::*", FileQueryInfoFlags.NONE, null);
          FileInfo? info = null;
          while ((info = enumerator.next_file()) != null) {
              if (info.get_file_type() == FileType.DIRECTORY)
                  continue;
              if (type_regex.match (info.get_name()))
                  try {
                          var pixmappath = pixmap_path + "/" + info.get_name();
                          map_icons[info.get_name()] = new Gdk.Pixbuf.from_file (pixmappath);
                          //debug_msg_level (3, _("Load pixmap: %s\n"), pixmappath);
                  } /*catch (Gdk.PixbufError e) {
                      errmsg (_("Could not load pixmap: %s\n"), e.message);
                  } catch (GLib.FileError e) {
                      errmsg (_("Could not open pixmaps file: %s\n"), e.message);
                  } catch (GLib.Error e) {
                      errmsg (_("Pixmap loading failed: %s\n"), e.message);
                  }*/
                  catch {}
          }
      } catch (GLib.Error e) {
          //warning_msg (_("Could not list or iterate through directory content of '%s': %s\n"),
          //             imagedir.get_path(), e.message);
      }
    }

    public Gdk.Pixbuf? get_pixbuf_for_symbol (string symbol_type) {
        var complete_typename = "element-" + symbol_type;//get_symbol_type_name(symbol);

        /*if (!(symbol is Vala.Signal))
            switch (symbol.access) {
                case SymbolAccessibility.INTERNAL:  //TODO: Add internal icons
                case SymbolAccessibility.PRIVATE:
                    complete_typename += "-private";
                    break;
                case SymbolAccessibility.PUBLIC:
                    if (!(symbol is Namespace))
                        complete_typename += "-public";
                    break;
                case SymbolAccessibility.PROTECTED:
                    if (!(symbol is Field))
                        complete_typename += "-protected";
                    break;
            }*/

        complete_typename += "-16.png";
        if (map_icons.has_key (complete_typename))
            return map_icons[complete_typename];
        return null;
    }

    public override void destroy() {
    }

 }

}
