# Valama #

The next gen Vala IDE.

## Manual installation ##

### Requirements
 * cmake (>= 2.8)
 * vala (>= 0.16) (0.18 is recommended)
 * pkg-config
 * gobject-2.0
 * glib-2.0
 * gio-2.0
 * gee-1.0 or gee-0.8
 * libvala-0.18 (>= 0.17) or libvala-0.16 (deprecated)
 * gdk-3.0
 * gdl-3.0 (>= 3.6 is recommended)
 * gtk+-3.0
 * gtksourceview-3.0
 * libxml-2.0
 * gthread-2.0

On Debian based system install following packages:

    sudo apt-get install build-essential valac-0.18 libvala-0.18-dev cmake pkg-config libgtk-3-dev libgtksourceview-3.0-dev libgee-dev libxml2-dev libgdl-3-dev

If `valac-0.18` and `libvala-0.18-dev` aren't available, replace them with `valac-0.16` and `libvala-0.16-dev`.

If you want to use `gee-0.8` instead of `gee-1.0`, change `cmake/project.cmake` and `cmake/guanako.cmake` accordingly.

### Building ###
 1. `mkdir build && cd build`
 1. `cmake ..`
 1. `make -j2`

### Installation ###
 1. `sudo make install` (real installation is required for syntax definitions and templates)


## Packaging files for distributions ##
To build and install Valama for your distriution look at the [packaging](https://github.com/Valama/valama/tree/packaging) branch. If you don't find your distribution there, you are welcome to contribute your packagig files to this branch (and put you work under GPL-3+).

## License ##
Valama is distributed under the terms of the GNU General Public License version 3 or later and published by:
 * Linus Seelinger
 * Dominique Lasserre

For a full list of all contributors see [here](https://github.com/Valama/valama/graphs/contributors) and take a look at `AUTHORS` file.

## Credits ##

element-\* icons from Anjuta IDE (www.anjuta.org, GPL2 licensed)
