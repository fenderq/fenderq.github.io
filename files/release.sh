#!/bin/sh
#
# Copyright (c) 2002-2019 Steven Roberts <sroberts@fenderq.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

# Last updated on 2019-03-30
# http://www.fenderq.com/files/release.sh

# Building the System from Source
# http://www.openbsd.org/faq/faq5.html

# Please set CVSROOT to one of your regional Available Anonymous CVS Servers.
# http://www.openbsd.org/anoncvs.html
CVSROOT=anoncvs@anoncvs1.usa.openbsd.org:/cvs

ARCH=amd64
DATEFMT=+%FT%T%z
GZIP=1
CORES=1
KERNEL=GENERIC.MP
OBJDIR=/usr/obj
PORTSPATH=/usr/ports
RELDIR=/home/rel-${ARCH}
RELXDIR=/home/relx-${ARCH}
START=`date ${DATEFMT}`
TAG=OPENBSD_6_5
VND=vnd1
XOBJDIR=/usr/xobj
XSRCDIR=/usr/xenocara

create_fs() {
	export VNDFS=`mktemp -t vndfs.XXXXXXXXXX` || exit 1
	dd if=/dev/zero of=${VNDFS} bs=1m count=1024
	vnconfig -v ${VND} ${VNDFS}
	fdisk -iy ${VND}
	printf "a\n\n\n\n\nw\nq\n" | disklabel -E ${VND}
	newfs /dev/r${VND}a
	export VNDMOUNT=`mktemp -dt vndmount.XXXXXXXXXX` || exit 1
	mount -o async,noatime,noperm /dev/${VND}a ${VNDMOUNT}
	chown build ${VNDMOUNT}
	chmod 700 ${VNDMOUNT}
}

remove_fs() {
	umount ${VNDMOUNT}
	vnconfig -v -u ${VND}
	rm -rf ${VNDFS} ${VNDMOUNT}
	unset VNDFS VNDMOUNT
}

superuser_check() {
	if [ `whoami` != "root" ]; then
		echo "You must be root to run this command option." 
		exit 1
	fi
}

update_sources() {
	echo "[`date ${DATEFMT}`] Update sources"
	echo "Update /usr/src ..."
	cd /usr/src && cvs -d ${CVSROOT} -z ${GZIP} update -r ${TAG} -Pd
	echo "Update ${XSRCDIR} ..."
	cd ${XSRCDIR} && cvs -d ${CVSROOT} -z ${GZIP} update -r ${TAG} -Pd
	echo "Update ${PORTSPATH} ..."
	cd ${PORTSPATH} && cvs -d ${CVSROOT} -z ${GZIP} update -r ${TAG} -Pd
}

build_kernel() {
	echo "[`date ${DATEFMT}`] Build and install a new kernel"
	superuser_check
	cd /sys/arch/${ARCH}/compile/${KERNEL}
	make obj
	make config
	make && make install
}

build_system() {
	echo "[`date ${DATEFMT}`] Build a new base system"
	superuser_check
	rm -rf ${OBJDIR}/*
	chown build.wobj ${OBJDIR}
	chmod 770 ${OBJDIR}
	cd /usr/src
	make obj && make -j ${CORES} build
}

make_system_release() {
	echo "[`date ${DATEFMT}`] Make and validate the base system release"
	superuser_check
	create_fs
	mkdir -p ${RELDIR}
	chown build ${RELDIR}
	export DESTDIR=${VNDMOUNT}; export RELEASEDIR=${RELDIR}
	cd /usr/src/etc && make release
	cd /usr/src/distrib/sets && sh checkflist
	unset RELEASEDIR DESTDIR
	remove_fs
}

build_xenocara() {
	echo "[`date ${DATEFMT}`] Build and install Xenocara"
	superuser_check
	rm -rf ${XOBJDIR}/*
	chown build.wobj ${XOBJDIR}
	chmod 770 ${XOBJDIR}
	cd ${XSRCDIR}
	make bootstrap
	make obj
	make -j ${CORES} build
}

make_xenocara_release() {
	echo "[`date ${DATEFMT}`] Make and validate the Xenocara release"
	superuser_check
	create_fs
	mkdir -p ${RELXDIR}
	chown build ${RELXDIR}
	export DESTDIR=${VNDMOUNT}; export RELEASEDIR=${RELXDIR}
	cd ${XSRCDIR}
	make release
	make checkdist
	unset RELEASEDIR DESTDIR
	remove_fs
}

create_disk_images() {
	echo "[`date ${DATEFMT}`] Create boot and installation disk images"
	superuser_check
	export RELDIR RELXDIR
	cd /usr/src/distrib/${ARCH}/iso && make
	make install
	unset RELDIR RELXDIR
}

usage() {
	echo "  Usage: $0 <options>" 
	echo 
	echo "Options:"
	echo 
	echo "  update           - Update sources" 
	echo "  kernel           - Build and install a new kernel"
	echo "  system           - Build a new system"
	echo "  system-release   - Make and validate the system release"
	echo "  xenocara         - Build and install xenocara"
	echo "  xenocara-release - Make and validate the xenocara release"
	echo "  disk-images      - Create boot and installation disk images"
	echo
}

echo
echo "release.sh - building an OpenBSD release(8)"
echo
echo " Kernel: ${KERNEL}-${ARCH}"
echo "Release: ${RELDIR}, ${RELXDIR}"
echo "    CVS: ${CVSROOT}"
echo "    TAG: ${TAG}"
echo

if [ $# = 0 ]; then
	usage
	exit 1;
fi

for i in $*; do
	case $i in
	update)
		update_sources
		;;
	kernel)
		build_kernel
		;;
	system)
		build_system
		;;
	system-release)
		make_system_release
		;;
	xenocara)
		build_xenocara
		;;
	xenocara-release)
		make_xenocara_release
		;;
	disk-images)
		create_disk_images
		;;
	*)
		echo "Invalid option encountered: $i"
		echo
		exit 1
		;; 
	esac
done

echo
echo " Start Time: ${START}"
echo "Finish Time: `date ${DATEFMT}`"
echo
