# Valama #

#### *The next gen Vala IDE.* ####

Discussion and support on IRC channel [#valama](http://webchat.freenode.net/?channels=#valama) (freenode).

![Valama 28.05.2013](https://raw.github.com/Valama/valama/gh-pages/images/valama_2013-05-28.png)

[![Build Status](https://travis-ci.org/Valama/valama.png)](https://travis-ci.org/Valama/valama)

## Manual installation ##

### Requirements
 * cmake (>= 2.8.4)
 * valac (>= 0.20), valac-0.24 or valac-0.26 is recommended
 * pkg-config
 * gobject-2.0
 * glib-2.0
 * gio-2.0
 * gladeui-2.0 (for glade files)
 * gee-0.8 (>= 0.10.5)
 * at least libvala-0.22 (recommended) or libvala-0.20
 * gdk-3.0
 * gdl-3.0 (>= 3.5.5 is recommended)
 * gtk+-3.0 (>= 3.6) 
 * gtksourceview-3.0, 3.12 is recommended for new features in SourceView
 * clutter-gtk-1.0
 * libxml-2.0
 * gthread-2.0
 * Intltool (required to generate .desktop and .xml files with localization)
 * GNOME desktop icon theme (symbolic icons) (only required to display icons properly) (recommended)
 * rsvg-convert/imagemagick (only required to generate application icons from svg template) (recommended)

On Debian based systems install following packages:

    sudo apt-get install build-essential valac-0.20 libvala-0.20-dev cmake pkg-config libgtksourceview-3.0-dev libgee-0.8-dev libxml2-dev libgdl-3-dev libgladeui-dev libclutter-gtk-1.0-dev intltool gnome-icon-theme-symbolic librsvg2-bin

For a newer vala version, you have to include the [Vala Team PPA](https://launchpad.net/~vala-team/+archive/ppa) first.

On Fedora based systems install following packages:

    sudo yum install vala-devel cmake gtksourceview3-devel glade3-libgladeui-devel libgee-devel libxml2-devel libgdl-devel clutter-gtk-devel intltool gnome-icon-theme-symbolic librsvg2

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
See the wiki page for some information [Wiki](https://github.com/Valama/valama/wiki) or drop in on [#valama](http://webchat.freenode.net/?channels=#valama) (irc.freenode.net).

## License ##
Valama is distributed under the terms of the GNU General Public License version 3 or later and published by:
 * Linus Seelinger
 * Dominique Lasserre

For a full list of all contributors see [here](https://github.com/Valama/valama/graphs/contributors) and take a look at [AUTHORS](https://github.com/Valama/valama/blob/master/AUTHORS) file.

## Credits ##
element-\* icons from [Anjuta IDE](https://projects.gnome.org/anjuta/) (GPL2 licensed)
