# Valama #

The next gen Vala IDE.

## Manual installation ##

### Requirements
 * cmake (>= 2.8)
 * valac (>= 0.17)
 * pkg-config
 * gobject-2.0
 * glib-2.0
 * gio-2.0
 * gee-1.0 or gee-0.8
 * libvala-0.18 (>= 0.17) or newer libvala
 * gdk-3.0
 * gdl-3.0 (>= 3.5.5 is recommended)
 * gtk+-3.0
 * gtksourceview-3.0
 * libxml-2.0
 * gthread-2.0

On Debian based system install following packages:

    sudo apt-get install build-essential valac-0.18 libvala-0.18-dev cmake pkg-config libgtk-3-dev libgtksourceview-3.0-dev libgee-dev libxml2-dev libgdl-3-dev

If you want to use `gee-0.8` instead of `gee-1.0`, change `cmake/project.cmake` and `cmake/guanako.cmake` accordingly.

If you want to use a newer version of `libvala`, change  `cmake/project.cmake` and `cmake/guanako.cmake` (and if you want to use Valama `valama.vlp`) accordingly.

### Building ###
 1. `mkdir build && cd build`
 1. `cmake ..`
 1. `make -j2`

### Installation ###
 1. `sudo make install` (real installation is required for syntax definitions and templates)


## Packaging files for distributions ##
To build and install Valama for your distriution look at the [packaging](https://github.com/Valama/valama/tree/packaging) branch. If you don't find your distribution there, you are welcome to contribute your packagig files to this branch (and put you work under GPL-3+).

## FAQ ##
### Valama build error: ‘GdlDockItem’ has no member named ‘child’ ###
With `gdl` >= 3.5.5 you have to update your gdl-vapi (see [#693127](https://bugzilla.gnome.org/show_bug.cgi?id=693127)). If your Vala version is 0.18 update the file `/usr/share/vala-0.18/vapi/gdl-3.0.vapi` with following patch:

```diff
--- a/gdl-3.0.vapi
+++ b/gdl-3.0.vapi
@@ -41,7 +41,7 @@
        }
        [CCode (cheader_filename = "gdl/gdl.h", type_id = "gdl_dock_item_get_type ()")]
        public class DockItem : Gdl.DockObject, Atk.Implementor, Gtk.Buildable {
-               public weak Gtk.Widget child;
+               public weak Gtk.Widget child { get; set; }
                public int dragoff_x;
                public int dragoff_y;
                [CCode (has_construct_function = false, type = "GtkWidget*")]
```

This will make DockItem.child a property and fix this C-compiler error.


## License ##
Valama is distributed under the terms of the GNU General Public License version 3 or later and published by:
 * Linus Seelinger
 * Dominique Lasserre

For a full list of all contributors see [here](https://github.com/Valama/valama/graphs/contributors) and take a look at `AUTHORS` file.

## Credits ##

element-\* icons from Anjuta IDE (www.anjuta.org, GPL2 licensed)
