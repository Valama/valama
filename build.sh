#!/bin/bash

valac --target-glib=2.32 --thread --pkg gtksourceview-3.0 --pkg libxml-2.0 --pkg gee-0.8 --pkg gtk+-3.0 --pkg libvala-0.22 --pkg clutter-gtk-1.0 -X -lm -o main $(find -name *.vala -printf "%p ")
