# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

# Patched ebuild for 2.8 from amdstream-2.6 in xarthisius overlay

EAPI=5

inherit eutils toolchain-funcs multilib

MY_PN=AMD-APP-SDK
MY_PV=v${PV}
MY_P=${MY_PN}-${MY_PV}

DESCRIPTION="AMD Accelerated Parallel Processing (APP) SDK (formerly ATI Stream)"
HOMEPAGE="http://developer.amd.com/sdks/amdappsdk/pages/default.aspx"

SRC_URI="amd64? ( http://developer.amd.com/wordpress/media/files/${MY_P}-lnx64.tgz )
	x86? ( http://developer.amd.com/wordpress/media/files/${MY_P}-lnx32.tgz )"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="examples"

#check if those deps are valid, especially llvm
RDEPEND="
	app-admin/eselect-opencl
	x11-libs/libXext
	x11-libs/libX11
	examples? (
		sys-devel/llvm
		media-libs/glew
		media-libs/freeglut
	)"
DEPEND=""

S=${WORKDIR}

RESTRICT="mirror fetch"
QA_PREBUILT="opt/AMDAPP/lib/*
	opt/AMDAPP/bin/clinfo
	opt/AMDAPP/samples/opencl/bin/x86_64/*
	opt/AMDAPP/samples/opencl/bin/x86/*"

pkg_setup() {
	if [[ $(tc-arch) == 'x86' ]] ; then
		bitness=32
		_arch=x86
		_narch=x86_64
	else
		bitness=64
		_arch=x86_64
		_narch=x86
	fi
	export bitness
	export _arch
	export MY_S=${MY_P}-RC-lnx${bitness}
}

src_unpack() {
	default_src_unpack
	unpack ./${MY_S}.tgz ./icd-registration.tgz
}

src_prepare() {
	local _ddir=/opt/AMDAPP/
	cat <<-EOF > 99${PN}
		PATH=${_ddir}bin
		LDPATH=${_ddir}lib
		AMDSTREAMSDKROOT=${_ddir}
		AMDSTREAMSDKSAMPLEROOT=${_ddir}
	EOF

	if use examples ; then
		pushd ${MY_S} &> /dev/null
		epatch "${FILESDIR}"/${P}-x11.patch \
			"${FILESDIR}"/${P}-parallel-build.patch
		sed -i make/openclsdkdefs.mk \
			-e "s/g++/$(tc-getCXX)/" \
			-e "/C_DEBUG_FLAG/d" || die #CXXFLAGS
		popd &> /dev/null
	fi
}

src_compile() {
	use examples || return
	#emake -C ${MY_S} # Does it make sense to build it?
}

src_install() {
	doenvd 99${PN}
	doins -r etc

	#Install SDK
	pushd ${MY_S} &> /dev/null
	insinto /opt/AMDAPP
	doins -r {glut_notice.txt,docs,include}
	
	if use examples ; then
		rm -rf samples/opencl/bin/${_narch}
		doins -r samples
		for i in /opt/AMDAPP/samples/opencl/bin/${_arch}/*; do
			[[ ${i} == ${i%.*} ]] && fperms 755 "${i}"
		done
	fi

	insopts -m755
	insinto /opt/AMDAPP/bin
	doins bin/${_arch}/clinfo

#	insinto /opt/AMDAPP/lib
#	rm -rf lib/${_arch}/lib{GLEW,glut}.so
#	doins lib/${_arch}/*.so lib/${_arch}/*

	insinto /opt/AMDAPP/
	rm -rf lib/*/lib{GLEW,glut}.so
	doins -r lib

	dodir /usr/$(get_libdir)/OpenCL/vendors/
	dosym /opt/AMDAPP/lib/${_arch}/ /usr/$(get_libdir)/OpenCL/vendors/amd
}

pkg_postinst() {
	eselect opencl set --use-old amd
}
