# Valama #

## Installation ##

### Requirements
 * cmake (>= 2.8)
 * vala (>= 0.16)
 * pkg-config
 * gtk+=3.0
 * gtksourceview-3.0
 * libvala-0.16

On Debian based system install following packages:
`sudo apt-get install build-essential vala-0.16 libvala-0.16-dev cmake libgtk-3-dev`

### Building ###
 1. `mkdir build && cd build`
 1. `cmake ..`
 1. `make -j2`

### Installation ###
 1. `sudo make install`