#!/bin/sh
#
# The configure options specified in this script are the same with those of
# RedHat (and CentOS) distribution (By N. Soda at SRA)
#
# ./build.sh SRCDIR PREFIX
# Arguments:
#	SRCDIR: root directory of the GLIB source code
#	PREFIX: the install directory
#

case $# in
2)	:;;
*)	echo >&2 "Usage: ./`basename $0` <SRCDIR> <PREFIX>"
	echo >&2 "	<SRCDIR>: root directory of the GLIB source code"
	echo >&2 "	<PREFIX>: the install directory"
	exit 2
	;;
esac

: ${BUILD_PARALLELISM=`getconf _NPROCESSORS_ONLN`}

case `uname -m` in
aarch64)
	opt_mtune=
	opt_add_ons=ports,nptl,c_stubs,libidn
	opt_build=aarch64-redhat-linux
	opt_multi_arch=
	opt_systemtap=--enable-systemtap
	opt_mflags=PARALLELMFLAGS=
	;;
x86_64)
	opt_mtune=-mtune=generic
	opt_add_ons=ports,nptl,rtkaio,c_stubs,libidn
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

set -x
make clean
make distclean
#
$1/configure --prefix=$2 CC=gcc CXX=g++ "CFLAGS=${opt_mtune} -fasynchronous-unwind-tables -DNDEBUG -g -O3 -fno-asynchronous-unwind-tables" --enable-add-ons=${opt_add_ons} --with-headers=/usr/include --enable-kernel=2.6.32 --enable-bind-now --build=${opt_build} ${opt_multi_arch} --enable-obsolete-rpc ${opt_systemtap} --disable-profile --enable-nss-crypt
#
make -j ${BUILD_PARALLELISM} ${opt_mflags}
make install ${opt_mflags}
