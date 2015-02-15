#!/bin/bash

glib-compile-resources ui_resources.xml --generate-source

valac --target-glib=2.38 --thread --gresources ui_resources.xml --pkg gladeui-2.0 --pkg gtksourceview-3.0 --pkg libxml-2.0 --pkg gee-0.8 --pkg gtk+-3.0 --pkg libvala-0.24 --pkg clutter-gtk-1.0 -X -lm -o main --vapidir=vapi --vapidir=/usr/share/vala-0.24/vapi ui_resources.c $(find -name *.vala -printf "%p ")
