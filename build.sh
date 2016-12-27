#!/usr/bin/sh
#
# The configure options specified in this script are the same with those of
# RedHat (and CentOS) distribution (By N. Soda at SRA)
#
# Environment Variables
#	SRCDIR: root directory of the GLIB source code
#	PREFIX: the install directory
#
make clean
make distclean
#
$SRCDIR/configure --prefix=$PREFIX CC=gcc CXX=g++ 'CFLAGS=-mtune=generic -fasynchronous-unwind-tables -DNDEBUG -g -O3  -fno-asynchronous-unwind-tables' --enable-add-ons=ports,nptl,rtkaio,c_stubs,libidn --with-headers=/usr/include --enable-kernel=2.6.32 --enable-bind-now --build=x86_64-redhat-linux --enable-multi-arch --enable-obsolete-rpc --enable-systemtap --disable-profile --enable-nss-crypt
#
make -j 4
make install
