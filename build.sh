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

check_packages() {
    pkgs_installed="`yum list available 2>/dev/null | cut -d ' ' -f 1 | cut -d '.' -f 1`";
    pkgs_needed="systemtap*-devel readline-devel ncurses-devel rpm-devel"

    pkgfail=false;
    for pkgn in $pkgs_needed; do
	nopkg=true;
	for pkgi in $pkgs_installed; do
	    case $pkgi in
		$pkgn) nopkg=false;
		       break;;
	    esac
	done
	if [ $nopkg == true ]; then
	    pkgfail=true;
	    echo "$pkgn must be installed"
	fi
    done
    if $pkgfail; then
	exit 1;
    fi
    echo "All required Yum packages are found."
}

cleanup()
{
    echo;
    echo "cleaning up ..."
    rm -f -r *;
    exit 2;
}

trap cleanup $BUILD_TRAP_SIGS;

cmd=`basename $0`

usage()
{
	echo >&2 "Usage: ./$cmd [-b] [-j<N>] <PREFIX>"
	echo >&2 "       ./$cmd -i <PREFIX>"
	echo >&2 "	-b      : build only, do not install" # for RPM
	echo >&2 "	-j<N>   : make parallelism"
	echo >&2 "	-i      : install only, do not build" # for RPM
	echo >&2 "	<PREFIX>: the install directory"
	exit 2
}

do_build=true
do_install=true
do_piplnlibs=true

: ${SRCDIR:=`dirname $0`}
: ${BUILD_PARALLELISM:=`getconf _NPROCESSORS_ONLN`}
: ${CC:=gcc}
: ${CXX:=g++}
: ${CFLAGS:='-O2 -g'}

pwd=`pwd`
cwd=`realpath ${pwd}`
rsrcdir=`realpath ${SRCDIR}`
if [ x"${cwd}" == x"${rsrcdir}" ]; then
    echo >&2 "Error: ${cmd} must be invoked at the different directory from the source tree"
    exit 1;
fi
cdir=`ls`
if [ x"${cdir}" != x ]; then
    echo >&2 "Warning: The current directory is not empty"
    echo >&2 "         If build.sh fails with compilation errors,"
    echo >&2 "         remove all files and directoris in this directory"
    echo >&2 "         and then try again."
fi

machine=`uname -m`
case ${machine} in
aarch64)
	opt_machine_flags=
	opt_static_pie=
	opt_cet=
	;;
x86_64)
	opt_machine_flags='-m64 -mtune=generic'
	opt_static_pie=
	opt_cet=
	;;
*)
	echo >&2 "$cmd: unsupported machine type: `uname -m`"
	exit 2
	;;
esac

if [ -f /etc/debian_version ]; then
	opt_distro=--disable-werror
else
	opt_distro=
fi

build_parallelism=

# -b is for %build phase, and -i is for %install phase of rpmbuild(8)
while	case "$1" in
	-b)	do_install=false
		do_piplnlibs=false
		true;;
	-i)	do_build=false
		do_piplnlibs=false
		true;;
	--prefix=*)
		prefix=`expr "$1" : "--prefix=\(.*\)"`; true;;
	-j*)
		build_parallelism=`expr "$1" : "-j\([0-9]*\)"`; true;;
	-*)	usage;;
	'')	false;;
	*)	prefix=$1; true;;
	esac
do
	shift
done

if [ x"$prefix" == x ]; then
    echo >&2 "Error: <PREFIX> must be specifgied"
    usage;
fi

case "$1" in
-*)	usage;;
esac

if [ x"${build_parallelism}" != x ]; then
    BUILD_PARALLELISM=${build_parallelism}
fi

set -x

if $do_build; then
	set +e
        # unlink $prefix/share not to be deleted by 'make clean'
	if [ -h $prefix/share ]; then
	    unlink $prefix/share
	fi
	$SRCDIR/configure CC="${CC}" CXX="${CXX}" \
		"CFLAGS=${CFLAGS} -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 ${opt_machine_flags} -fasynchronous-unwind-tables -fstack-clash-protection" \
		--prefix=$prefix \
		--with-headers=/usr/include \
		--enable-kernel=3.2 \
		--with-nonshared-cflags=' -Wp,-D_FORTIFY_SOURCE=2' \
		--enable-bind-now \
		--build=${machine}-redhat-linux \
		--enable-stack-protector=strong \
		${opt_static_pie} \
		--enable-tunables \
		--enable-systemtap \
		${opt_cet} \
		--disable-profile \
		--disable-crypt \
		--enable-process-in-process

	make -j${BUILD_PARALLELISM} -O -r 'ASFLAGS=-g -Wa,--generate-missing-build-notes=yes'
	if [ $? != 0 ]; then
	    echo >&2 "PiP-glibc build error"
	    exit 1;
	fi
#	make localedata/install-locales
fi

# installation should honor ${DESTDIR}, especially for rpmbuild(8)
if $do_install; then
        # unlink $prefix/share not to be deleted by 'make install'
	if [ -h ${DESTDIR}$prefix/share ]; then
	    unlink ${DESTDIR}$prefix/share
	fi
	# do make install PiP-glibc
	make install
	# then mv the installed $prefix/share to share.pip. 'rm -r' if exists
	if [ -d ${DESTDIR}$prefix/share ] && ! [ -h ${DESTDIR}$prefix/share ]; then
	    if [ -d ${DESTDIR}$prefix/share.pip ]; then
		rm -r ${DESTDIR}$prefix/share.pip
	    fi
	    mv -f ${DESTDIR}$prefix/share ${DESTDIR}$prefix/share.pip
	fi
	# finally symbolic link to /usr/share
	if ! [ -h ${DESTDIR}$prefix/share ]; then
	    ln -s /usr/share ${DESTDIR}$prefix/share
	fi

	# workaround (removing RPATH in ld-liux.so)
	rm -f pip_annul_rpath
	${CC} -g -O2 ${SRCDIR}/pip_annul_rpath.c -o pip_annul_rpath
	ld_linux=`ls -d ${DESTDIR}$prefix/lib/ld-[0-9]*.so | sed -n '$p'`
	./pip_annul_rpath ${ld_linux}

	# make and install piplnlibs.sh
	if ! [ -d ${DESTDIR}$prefix/bin ]; then
	    mkdir -p ${DESTDIR}$prefix/bin
	fi
	sed "s|@GLIBC_PREFIX@|$prefix|" < ${SRCDIR}/piplnlibs.sh.in > ${DESTDIR}${prefix}/bin/piplnlibs
	chmod +x ${DESTDIR}${prefix}/bin/piplnlibs

	if ${do_piplnlibs}; then
	    # for RPM, this has to be done at "rpm -i" instead of %install phase
	    ( unset LD_LIBRARY_PATH; ${DESTDIR}${prefix}/bin/piplnlibs -s )
	fi
fi
