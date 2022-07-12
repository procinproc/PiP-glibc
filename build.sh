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

# ./build.sh PREFIX
# Arguments:
#	PREFIX: the install directory
#

BUILD_TRAP_SIGS='1 2 14 15';

echo $0 $@ > .build.cmd

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
	echo >&2 "Usage: ./$cmd [-j<N>] <PREFIX>"
	echo >&2 "	-j<N>   : make parallelism"
	echo >&2 "	<PREFIX>: the install directory"
	exit 2
}

do_build=true
do_install=true
do_piplnlibs=true

dir=`dirname $0`
srcdir=`cd $dir; pwd`

: ${SRCDIR:=${srcdir}}
: ${BUILD_PARALLELISM:=`getconf _NPROCESSORS_ONLN`}
: ${CC:=gcc}
: ${CXX:=g++}

pwd=`pwd`
cwd=`realpath ${pwd}`
rsrcdir=`realpath ${SRCDIR}`
if [ x"${cwd}" == x"${rsrcdir}" ]; then
    echo >&2 "Error: ${cmd} must be invoked at the different directory from the source tree"
    exit 1;
fi

build_parallelism=

# -b is for %build phase, and -i is for %install phase of rpmbuild(8)
while	case "$1" in
	-b)	do_install=false # for RPM build
		do_piplnlibs=false
		true;;
	-i)	do_build=false	# for RPM build
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

if [ x"${prefix}" == x ]; then
    echo >&2 "Error: <PREFIX> must be specifgied"
    usage;
fi

case "$1" in
-*)	usage;;
esac

if [ x"${build_parallelism}" != x ]; then
    BUILD_PARALLELISM=${build_parallelism}
fi

echo "Checking required packages ... "

enable_nss_crypt=
enable_systemtap=

pkg_check=true
nopkg=false
for pkgn in $pkgs_needed; do
    if yum list installed $pkgn >/dev/null 2>&1; then
	case ${pkgn} in
	    nss) nss_config=`which nss-config 2> /dev/null`;
		if [ z"${nss_config}" != z -a -x ${nss_config} ]; then
		     enable_nss_crypt="--enable-nss-crypt"
	         fi;;
	esac
    elif ! [ -d ${SRCDIR}/header-import/${pkgn} ]; then
	    CPPFLAGS="-I${SRCDIR}/header-import/${pkgn}"
    else
        echo "'$pkgn' package is not installed but required"
	pkg_check=false
    fi
    if [ x"${pkgs}" == x"systemtap" ]; then
	if [ -f /usr/include/sys/sdt.h ]; then
	    enable_systemtap="--enable-systemtap"
	fi
    fi
done

if $pkg_check; then
    echo "All required packages found"
else
    echo "Some packages are missing"
    exit 1
fi

case `uname -m` in
aarch64)
	opt_mtune=
	opt_add_ons=nptl,c_stubs,libidn
	opt_build=aarch64-redhat-linux
	opt_multi_arch=
	opt_mflags=PARALLELMFLAGS=
	;;
x86_64)
	opt_mtune=-mtune=generic
	opt_add_ons=nptl,rtkaio,c_stubs,libidn
	opt_build=x86_64-redhat-linux
	opt_multi_arch=--enable-multi-arch
	opt_mflags=
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

set -x

# The configure options specified in this script are the same with those of
# RedHat (and CentOS) distribution (By N. Soda at SRA)

if $do_build; then
	set +e
        # unlink ${prefix}/share not to be deleted by 'make clean'
	if [ -h ${DESTDIR}${prefix}/share ]; then
	    unlink ${DESTDIR}${prefix}/share
	fi
	# make clean
	# make distclean
	rm -rf *
	set -e
	$SRCDIR/configure --prefix=${prefix} \
	    CC="${CC}" CXX="${CXX}" \
	    CFLAGS="${CFLAGS} ${opt_mtune} -fasynchronous-unwind-tables -DNDEBUG -g -O3 -fno-asynchronous-unwind-tables" \
	    --enable-add-ons=${opt_add_ons} \
	    --with-headers=/usr/include \
	    --enable-kernel=2.6.32 \
	    --enable-bind-now \
	    --enable-process-in-process \
	    --build=${opt_build} \
	    ${opt_multi_arch} \
	    --enable-obsolete-rpc \
	    ${enable_systemtap} \
	    --disable-profile \
	    ${enable_nss_crypt} \
	    ${opt_distro}
	make -j${BUILD_PARALLELISM} ${opt_mflags}
fi

# installation should honor ${DESTDIR}, especially for rpmbuild(8)
if $do_install; then
        # unlink ${prefix}/share not to be deleted by 'make install'
	if [ -h ${DESTDIR}${prefix}/share ]; then
	    unlink ${DESTDIR}${prefix}/share
	fi
	# do make install PiP-glibc
	make install ${opt_mflags}
	# then mv the installed $prefix/share to share.pip-glibc. 'rm -r' if exists
	if [ -d ${DESTDIR}${prefix}/share ]; then
	    if [ -d ${DESTDIR}${prefix}/share.pip-glibc ]; then
		rm -r -f ${DESTDIR}${prefix}/share.pip-glibc
	    fi
	    mv -f ${DESTDIR}${prefix}/share ${DESTDIR}${prefix}/share.pip-glibc
	fi
	# finally symbolic link to /usr/share
	ln -s /usr/share ${DESTDIR}${prefix}/share
	# workaround (removing RPATH in ld-liux.so)
	rm -f pip_annul_rpath
	${CC} -g -O2 ${SRCDIR}/pip_annul_rpath.c -o pip_annul_rpath
	ld_linux=`ls -d ${DESTDIR}$prefix/lib/ld-[0-9]*.so | sed -n '$p'`
	./pip_annul_rpath ${ld_linux}
	# make and install piplnlibs.sh
	if ! [ -d ${DESTDIR}${prefix}/bin ]; then
	    mkdir -p ${DESTDIR}${prefix}/bin
	fi
	sed "s|@GLIBC_PREFIX@|${prefix}|" \
	    < ${SRCDIR}/piplnlibs.sh.in > ${DESTDIR}${prefix}/bin/piplnlibs
	chmod +x ${DESTDIR}${prefix}/bin/piplnlibs

	if ${do_piplnlibs}; then
	    # for RPM, this has to be done at "rpm -i" instead of %install phase
	    ( unset LD_LIBRARY_PATH; ${DESTDIR}${prefix}/bin/piplnlibs -s -r )
	fi
fi

if [ x${enable_nss_crypt} == x ]; then
    echo "Warning: '--enable-nns-crypt' has been disabled"
fi
