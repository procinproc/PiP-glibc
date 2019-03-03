#!/bin/sh
#
# $RIKEN_copyright: 2018 Riken Center for Computational Sceience, 
# 	  System Software Devlopment Team. All rights researved$
#
# The GNU C Library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# The GNU C Library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with the GNU C Library; if not, see
# <http://www.gnu.org/licenses/>.

# The configure options specified in this script are the same with those of
# RedHat (and CentOS) distribution (By N. Soda at SRA)
#
# ./build.sh PREFIX
# Arguments:
#	PREFIX: the install directory
#

usage()
{
	echo >&2 "Usage: ./`basename $0` [-b] <PREFIX>"
	echo >&2 "       ./`basename $0`  -i"
	echo >&2 "	-b      : build only, do not install"
	echo >&2 "	-i      : install only, do not build"
	echo >&2 "	<PREFIX>: the install directory"
	exit 2
}

do_build=true
do_install=true

: ${SRCDIR:=`dirname $0`}
: ${BUILD_PARALLELISM:=`getconf _NPROCESSORS_ONLN`}
: ${CC:=gcc}
: ${CXX:=g++}

case `uname -m` in
aarch64)
	opt_mtune=
	opt_add_ons=nptl,c_stubs,libidn
	opt_build=aarch64-redhat-linux
	opt_multi_arch=
	opt_systemtap=--enable-systemtap
	opt_mflags=PARALLELMFLAGS=
	;;
x86_64)
	opt_mtune=-mtune=generic
	opt_add_ons=nptl,rtkaio,c_stubs,libidn
	opt_build=x86_64-redhat-linux
	opt_multi_arch=--enable-multi-arch
	opt_systemtap=--enable-systemtap
	opt_mflags=
	;;
*)
	echo >&2 "`basename $0`: unsupported machine type: `uname -m`"
	exit 2
	;;
esac

if [ -f /etc/debian_version ]; then
	opt_distro=--disable-werror
else
	opt_distro=
fi

case "$1" in
-b)	do_install=false; shift;;
-i)	do_build=false; shift;;
-*)	usage;;
esac

case "$1" in
-*)	usage;;
esac

if $do_build; then
	case $# in
	1)	:;;
	*)	usage;;
	esac
else
	case $# in
	0)	:;;
	*)	usage;;
	esac
fi

set -x

if $do_build; then
	make clean
	make distclean

	$SRCDIR/configure --prefix=$1 CC="${CC}" CXX="${CXX}" "CFLAGS=${CFLAGS} ${opt_mtune} -fasynchronous-unwind-tables -DNDEBUG -g -O3 -fno-asynchronous-unwind-tables" --enable-add-ons=${opt_add_ons} --with-headers=/usr/include --enable-kernel=2.6.32 --enable-bind-now --build=${opt_build} ${opt_multi_arch} --enable-obsolete-rpc ${opt_systemtap} --disable-profile --enable-nss-crypt ${opt_distro}

	make -j ${BUILD_PARALLELISM} ${opt_mflags}
fi

if $do_install; then
	make install ${opt_mflags}
fi
