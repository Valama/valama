# Valama #

The next gen Vala IDE.

![Valama 28.05.2013](https://raw.github.com/Valama/valama/gh-pages/images/valama_2013-05-28.png)

## Manual installation ##

### Requirements
 * cmake (>= 2.8.4)
 * valac (>= 0.17)
 * pkg-config
 * gobject-2.0
 * glib-2.0
 * gio-2.0
 * gee-0.8
 * at least libvala-0.22 (recommended) or libvala-0.20 or libvala-0.18
 * gdk-3.0
 * gdl-3.0 (>= 3.5.5 is recommended)
 * gtk+-3.0 (>= 3.4)
 * gtksourceview-3.0
 * libxml-2.0
 * gthread-2.0
 * Intltool (required to generate .desktop and .xml files with localization)
 * GNOME desktop icon theme (symbolic icons) (only required to display icons properly)
 * rsvg-convert (only required to generate application icons from svg template) (recommended)

On Debian based systems install following packages:

    sudo apt-get install build-essential valac-0.20 libvala-0.20-dev cmake pkg-config libgtksourceview-3.0-dev libgee-0.8-dev libxml2-dev libgdl-3-dev intltool gnome-icon-theme-symbolic librsvg2-bin

On Fedora based systems install following packages:

    sudo yum install vala-devel cmake gtksourceview3-devel libgee-devel libxml2-devel libgdl-devel intltool gnome-icon-theme-symbolic librsvg2

### Building ###
 1. `mkdir build && cd build`
 1. `cmake ..`
 1. `make -j2`

### Installation ###
 1. `sudo make install`
 1. `sudo ldconfig` (to update linker cache for the shared Guanako helper library)

This will automatically install and compile gsettings schemas. (You can
disable installtion/removal hooks during compile time with
`-DPOSTINSTALL_HOOK=OFF` option.)

#### Local installation ####
Build Valama then run with following options directly from build directory:

    XDG_DATA_DIRS=".:$XDG_DATA_DIRS" LD_LIBRARY_PATH=guanako ./valama --syntax ../guanako/data/syntax --templates ../data/templates --buildsystems ../data/buildsystems [FILE]

Optionally use `--layout ../data/layout.xml` to use standard layout.


## Packaging files for distributions ##
To build and install Valama for your distribution look at the [packaging](https://github.com/Valama/valama/tree/packaging) branch. If you don't find your distribution there, you are welcome to contribute your packaging files to this branch (and put you work under GPL-3+).


## Contribution ##
See the wiki page for some information: [Wiki](https://github.com/Valama/valama/wiki)

## License ##
Valama is distributed under the terms of the GNU General Public License version 3 or later and published by:
 * Linus Seelinger
 * Dominique Lasserre

For a full list of all contributors see [here](https://github.com/Valama/valama/graphs/contributors) and take a look at `AUTHORS` file.

## Credits ##
element-\* icons from [Anjuta IDE](https://projects.gnome.org/anjuta/) (GPL2 licensed)
