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

BUILD_TRAP_SIGS='1 2 14 15';

cleanup()
{
    echo;
    echo "cleaning up ..."
    rm -f -r *;
    exit 2;
}

trap cleanup $BUILD_TRAP_SIGS;

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
: ${CFLAGS:='-O2 -g'}

case `uname -m` in
aarch64)
	opt_machine_flags=
	opt_mtune=
	opt_build=aarch64-redhat-linux
	;;
x86_64)
	opt_machine_flags=-m64
	opt_mtune=-mtune=generic
	opt_build=x86_64-redhat-linux
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

	$SRCDIR/configure --prefix=$1 CC="${CC}" CXX="${CXX}" "CFLAGS=${CFLAGS} -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 ${opt_machine_flags} ${opt_mtune} -fasynchronous-unwind-tables -fstack-clash-protection" --with-headers=/usr/include --enable-kernel=3.2 '--with-nonshared-cflags= -Wp,-D_FORTIFY_SOURCE=2' --enable-bind-now --build=${opt_build} --enable-stack-protector=strong --enable-static-pie --enable-tunables --enable-systemtap --enable-cet --disable-profile --disable-crypt

	make -j ${BUILD_PARALLELISM} -O -r 'ASFLAGS=-g -Wa,--generate-missing-build-notes=yes'

fi

if $do_install; then
	make install
fi
