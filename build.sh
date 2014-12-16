#!/bin/bash

valac --target-glib=2.32 --thread --pkg gladeui-2.0 --pkg gtksourceview-3.0 --pkg libxml-2.0 --pkg gee-0.8 --pkg gtk+-3.0 --pkg libvala-0.24 --pkg clutter-gtk-1.0 -X -lm -o main --vapidir=vapi $(find -name *.vala -printf "%p ")
