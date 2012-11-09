# Valama #

The next gen Vala IDE.

## Installation ##

### Requirements
 * cmake (>= 2.8)
 * vala (>= 0.16) (0.18 is recommended)
 * pkg-config
 * gobject-2.0
 * glib-2.0
 * gio-2.0
 * gee-1.0
 * libvala-0.18 (>= 0.17) or libvala-0.16 (deprecated)
 * gdk-3.0
 * gtk+-3.0
 * gtksourceview-3.0
 * libxml-2.0
 * gthread-2.0

On Debian based system install following packages:
`sudo apt-get install build-essential valac-0.18 libvala-0.18-dev cmake pkg-config libgtk-3-dev libgtksourceview-3.0-dev libgee-dev libxml2-dev`

If `valac-0.18` and `libvala-0.18-dev` aren't available, replacte them with `valac-0.18` and `libvala-0.18-dev`.

### Building ###
 1. `mkdir build && cd build`
 1. `cmake ..`
 1. `make -j2`

### Installation ###
 1. `sudo make install` (real installation is required for syntax definitions)

# Credits #

element-\* icons from Anjuta IDE (www.anjuta.org, GPL2 licensed)
