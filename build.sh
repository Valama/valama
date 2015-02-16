#!/bin/bash

pkg_version()
{
	package=$1
	version=`pkg-config $package --modversion`
    check=$2
    win=`echo -e "$version\n$check" | sed '/^$/d' | sort -nr | head -1`
    if [ "$version" = "$check" ]; then
		echo "equal"
    elif [ "$win" = "$check" ]; then
		echo "less"
	elif [ "$win" = "$version" ]; then
		echo "greater"
	fi
}

valac_version()
{
	version=`valac --version`
	version=${version/Vala /}
	arr=(${version//./ })
	maj=${arr[0]}
	min=${arr[1]}
	odd=$((min % 2))
	if [ ${odd} = 1 ]; then
		min=$((min + 1))
	elif [ ${#arr[@]} -gt 3 ]; then
		min=$((min + 2))
	fi
	echo "${maj}.${min}"
}

# define some adjustement variables

gtksv_res=`pkg_version gtksourceview-3.0 3.15.3`
gtksv_define='GTK_SOURCE_VIEW_3_14'
if [ "$gtksv_res" = "equal" ] || [ "$gtksv_res" = "greater" ]; then
	gtksv_define='GTK_SOURCE_VIEW_3_15_3'
fi	

vv=`valac_version`

glib-compile-resources ui_resources.xml --generate-source

valac --define=${gtksv_define} --target-glib=2.38 --thread --gresources ui_resources.xml --pkg gladeui-2.0 --pkg gtksourceview-3.0 --pkg libxml-2.0 --pkg gee-0.8 --pkg gtk+-3.0 --pkg libvala-${vv} --pkg clutter-gtk-1.0 -X -lm -o main --vapidir=vapi ui_resources.c $(find -name *.vala -printf "%p ")
