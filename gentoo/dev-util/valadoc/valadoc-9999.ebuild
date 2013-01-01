# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4
inherit autotools git-2

DESCRIPTION="a documentation generator for Vala source code"
HOMEPAGE="https://live.gnome.org/Valadoc"
EGIT_REPO_URI="git://git.gnome.org/valadoc"
EGIT_BOOTSTRAP="eautoreconf"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""
IUSE=""

RDEPEND="dev-lang/vala:0.18
	>=dev-libs/glib-2.12:2
	>=dev-libs/libgee-0.8
	>=media-gfx/graphviz-2.16
	x11-libs/gdk-pixbuf:2
	>=x11-libs/gtk+-2.10:2"
DEPEND="${RDEPEND}
	dev-util/pkgconfig"

DOCS=( AUTHORS MAINTAINERS THANKS )

src_configure() {
	VALAC="$(type -p valac-0.18)" econf --disable-static
}

src_install() {
	default
	find "${ED}" -name "*.la" -type f -exec rm -rf {} + || die
}

