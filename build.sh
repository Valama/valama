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

vte_version()
{
	v="$(pkg-config vte-2.91 --modversion 2>&1 > /dev/null)"
	if [ -z "$v" ]
	then
		echo "2.91"
	else
		echo "2.90"
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

gtksv_res=`pkg_version gtksourceview-3.0 3.14.3`
gtksv_define='GTK_SOURCE_VIEW_3_14'
if [ "$gtksv_res" = "equal" ] || [ "$gtksv_res" = "greater" ]; then
	gtksv_define='GTK_SOURCE_VIEW_3_14_3'
fi	

vv=`valac_version`

vte=`vte_version`
vte_define="VTE_2_91"
if [ "$vte" = "2.90" ]; then
	vte_define="VTE_2_90"
fi

glib-compile-resources ui_resources.xml --generate-source

valac -X -DGETTEXT_PACKAGE="\"valamang\"" --define=${vte_define} --define=${gtksv_define} --target-glib=2.38 --thread --gresources ui_resources.xml --pkg gladeui-2.0 --pkg posix --pkg gtksourceview-3.0 --pkg libxml-2.0 --pkg gee-0.8 --pkg gtk+-3.0 --pkg vte-${vte} --pkg libvala-${vv} --pkg clutter-gtk-1.0 -X -lm -o main --vapidir=vapi/gladeui-2.0 ui_resources.c $(find -name *.vala -printf "%p ")
