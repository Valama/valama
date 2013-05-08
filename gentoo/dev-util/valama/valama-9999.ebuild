# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-util/valama/valama-9999.ebuild, 2012/12/16 09:01:08 Overscore $

EAPI=4

inherit base git-2 cmake-utils

CMAKE_MIN_VERSION="${CMAKE_MIN_VERSION:-2.8}"
CMAKE_BUILD_DIR="${WORKDIR}"
BUILD_DIR="${WORKDIR}"

DESCRIPTION="Next generation Vala IDE"
HOMEPAGE="http://valama.github.com/valama"

SRC_URI=""
EGIT_REPO_URI="git://github.com/Valama/valama.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

IUSE=""

CMAKE_BUILD_TYPE="Release"
S="${WORKDIR}"

DEPEND=">=dev-lang/vala-0.18
        >=dev-util/cmake-2.8.5
          dev-util/pkgconfig
        >=dev-libs/glib-2
        >=x11-libs/gtk+-3.4
        >=dev-libs/gdl-3.5.5
        >=x11-libs/gtksourceview-3
        >=dev-libs/libxml2-2
        >=dev-libs/libgee-0.8
        >=x11-themes/gnome-icon-theme-symbolic-3.4.0
        dev-util/valadoc"
RDEPEND="${DEPEND}"

src_configure() {
    cmake-utils_src_configure || die "Configure failed."
}

src_compile() {
    cmake-utils_src_compile || die "Compile failed."
}

src_install() {
    cmake-utils_src_install || die "Install failed."
}

