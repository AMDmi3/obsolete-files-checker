#!/bin/sh
#
# Copyright (c) 2012 Dmitry Marakasov.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

OFCDIR=`dirname "$0"`

set -u

# Suck in config file, if any
if [ -e "$OFCDIR/config" ]; then
	. "$OFCDIR/config"
fi

# Setup defaults
if [ -z "$SRCDIR" ]; then
	SRCDIR=/usr/src
fi

if [ -z "$TMPDIR" ]; then
	TMPDIR=/tmp/obsolete-files-checker
fi

if [ -z "$OUTDIR" ]; then
	OUTDIR="$OFCDIR"/output
fi

# Useful subroutines
fatal() {
	echo "$@"
	exit 1
}

forced_rmdir() {
	for dir in "$@"; do
		if [ -e "$dir" ]; then
			chflags -R noschg "$dir"
			rm -rf "$dir"
		fi
	done
}

# All knobs (please check if this is complete)
all_knobs="
	WITHOUT_ACCT
	WITHOUT_ACPI
	WITHOUT_AMD
	WITHOUT_APM
	WITHOUT_ASSERT_DEBUG
	WITHOUT_AT
	WITHOUT_ATM
	WITHOUT_AUDIT
	WITHOUT_AUTHPF
	WITHOUT_BIND
	WITHOUT_BIND_DNSSEC
	WITHOUT_BIND_ETC
	WITHOUT_BIND_LIBS
	WITHOUT_BIND_LIBS_LWRES
	WITHOUT_BIND_MTREE
	WITHOUT_BIND_NAMED
	WITHOUT_BIND_UTILS
	WITHOUT_BINUTILS
	WITHOUT_BLUETOOTH
	WITHOUT_BOOT
	WITHOUT_BSD_CPIO
	WITHOUT_BSNMP
	WITHOUT_BZIP2
	WITHOUT_BZIP2_SUPPORT
	WITHOUT_CALENDAR
	WITHOUT_CAPSICUM
	WITHOUT_CDDL
	WITHOUT_CLANG
	WITHOUT_CPP
	WITHOUT_CRYPT
	WITHOUT_CTM
	WITHOUT_CVS
	WITHOUT_CXX
	WITHOUT_DICT
	WITHOUT_DYNAMICROOT
	WITHOUT_ED_CRYPTO
	WITHOUT_EXAMPLES
	WITHOUT_FDT
	WITHOUT_FLOPPY
	WITHOUT_FORTH
	WITHOUT_FP_LIBC
	WITHOUT_FREEBSD_UPDATE
	WITHOUT_GAMES
	WITHOUT_GCC
	WITHOUT_GCOV
	WITHOUT_GDB
	WITHOUT_GNU
	WITHOUT_GNU_SUPPORT
	WITHOUT_GPIB
	WITHOUT_GPIO
	WITHOUT_GROFF
	WITHOUT_GSSAPI
	WITHOUT_HTML
	WITHOUT_INET
	WITHOUT_INET6
	WITHOUT_INET6_SUPPORT
	WITHOUT_INET_SUPPORT
	WITHOUT_INFO
	WITHOUT_IPFILTER
	WITHOUT_IPFW
	WITHOUT_IPX
	WITHOUT_IPX_SUPPORT
	WITHOUT_JAIL
	WITHOUT_KERBEROS
	WITHOUT_KERBEROS_SUPPORT
	WITHOUT_KERNEL_SYMBOLS
	WITHOUT_KVM
	WITHOUT_KVM_SUPPORT
	WITHOUT_LEGACY_CONSOLE
	WITHOUT_LIB32
	WITHOUT_LIBPTHREAD
	WITHOUT_LIBTHR
	WITHOUT_LOCALES
	WITHOUT_LOCATE
	WITHOUT_LPR
	WITHOUT_LS_COLORS
	WITHOUT_MAIL
	WITHOUT_MAILWRAPPER
	WITHOUT_MAKE
	WITHOUT_MAN
	WITHOUT_MAN_UTILS
	WITHOUT_NCP
	WITHOUT_NDIS
	WITHOUT_NETCAT
	WITHOUT_NETGRAPH
	WITHOUT_NETGRAPH_SUPPORT
	WITHOUT_NIS
	WITHOUT_NLS
	WITHOUT_NLS_CATALOGS
	WITHOUT_NS_CACHING
	WITHOUT_NTP
	WITHOUT_OBJC
	WITHOUT_OPENSSH
	WITHOUT_OPENSSL
	WITHOUT_PAM
	WITHOUT_PAM_SUPPORT
	WITHOUT_PF
	WITHOUT_PKGTOOLS
	WITHOUT_PMC
	WITHOUT_PORTSNAP
	WITHOUT_PPP
	WITHOUT_PROFILE
	WITHOUT_QUOTAS
	WITHOUT_RCMDS
	WITHOUT_RCS
	WITHOUT_RESCUE
	WITHOUT_ROUTED
	WITHOUT_SENDMAIL
	WITHOUT_SETUID_LOGIN
	WITHOUT_SHAREDOCS
	WITHOUT_SOURCELESS
	WITHOUT_SOURCELESS_HOST
	WITHOUT_SOURCELESS_UCODE
	WITHOUT_SSP
	WITHOUT_SYMVER
	WITHOUT_SYSCONS
	WITHOUT_SYSINSTALL
	WITHOUT_TCSH
	WITHOUT_TELNET
	WITHOUT_TEXTPROC
	WITHOUT_TOOLCHAIN
	WITHOUT_USB
	WITHOUT_UTMPX
	WITHOUT_WIRELESS
	WITHOUT_WIRELESS_SUPPORT
	WITHOUT_WPA_SUPPLICANT_EAPOL
	WITHOUT_ZFS
	WITHOUT_ZONEINFO

	WITHOUT_MAILWRAPPER+WITHOUT_SENDMAIL
"

# Ignore src.conf and make.conf, as they interfere the results
export SRCCONF=/var/empty/nonexistent
export __MAKE_CONF=/var/empty/nonexistent

# Setup environement for buildworld/installworld
export MAKEOBJDIRPREFIX="$TMPDIR/obj"
export DESTDIR="$TMPDIR/dest"

# Process flags
incremental=
buildworld=
clean=
while getopts ibch o; do
	case "$o" in
	b)
		buildworld=yes
		;;
	c)
		clean=yes
		;;
	i)
		incremental=yes
		;;
	*)
		echo "Usage: $0 [-b] [-c] [-i] [knobs ...]" 1>&2
		exit 1
		;;
	esac
done

shift $(($OPTIND-1))

# Rest of arguments are knobs
if [ -n "$*" ]; then
	all_knobs="$@"
fi

# If there's no obj, world just has to be built
if [ ! -e "$MAKEOBJDIRPREFIX" ]; then
	buildworld=yes
fi

# Check settings
echo "SRCDIR: $SRCDIR"
echo "TMPDIR: $TMPDIR"
echo "  OBJDIR: $MAKEOBJDIRPREFIX"
echo " DESTDIR: $DESTDIR"
echo "OUTDIR: $OUTDIR"
if [ -n "$buildworld" ]; then
	echo "* Will (re)build world"
else
	echo "* Will use pre-build world"
fi
if [ -n "$incremental" ]; then
	echo "* Incremental run"
else
	echo "* Normal run (from scratch)"
fi
echo "Testing knobs: `echo $all_knobs`"
echo

read -p "Is this correct [Y/n]? " answer

if echo "$answer" | grep -qi n; then
	exit 1
fi

mkdir -p "$OUTDIR"

# Buildworld
if [ -n "$buildworld" ]; then
	echo "===> Running buildworld..."
	forced_rmdir "$TMPDIR"
	cd "$SRCDIR" || fatal "Cannot cd into SRCDIR!"
	make -j `sysctl -n hw.ncpu` buildworld > "$OUTDIR/buildworld.log" 2>&1 || fatal "buildworld failed!"
fi

# Run checks for each knob
for knob in $all_knobs; do
	env=`echo $knob | sed -e 's|+| |; s|[^ ]*|&=yes|g'`
	knobs=`echo $knob | sed -e 's|+| |'`
	this_outdir="$OUTDIR/$knob"

	# Skip for incremental build only if current knob was tried and it showed no leftovers
	if [ -n "$incremental" -a -e "$this_outdir/leftovers" -a ! -s "$this_outdir/leftovers" ]; then
		echo "===> Skipping $knob: no leftovers detected in previous run"
		continue
	fi

	echo "===> Processing $knob..."
	forced_rmdir "$this_outdir" "$DESTDIR"
	mkdir -p "$this_outdir"

	echo "====> Modified installworld ($env)..."
	mkdir -p "$DESTDIR" || fatal "Cannot create DESTDIR!"
	cd "$SRCDIR" || fatal "Cannot cd into SRCDIR!"
	time env $env make installworld distribution > "$this_outdir/installworld.modified.log" 2>&1 || fatal "installworld failed!"

	echo "====> Gathering file lists..."
	cd "$DESTDIR" || fatal "Cannot cd into DESTDIR!"
	find -ds . | cut -b 2- > "$this_outdir/list.all"
	find -ds . -type f | cut -b 2- > "$this_outdir/list.files"
	find -ds . -type d | cut -b 2- > "$this_outdir/list.dirs"
	find -ds . -type l | cut -b 2- > "$this_outdir/list.links"

	echo "====> Cleaning up..."
	forced_rmdir "$DESTDIR"

	echo "====> Default installworld..."
	mkdir -p "$DESTDIR" || fatal "Cannot create DESTDIR!"
	cd "$SRCDIR" || fatal "Cannot cd into SRCDIR!"
	time make installworld distribution > "$this_outdir/installworld.default.log" 2>&1 || fatal "installworld failed!"

	echo "====> Running delete-old..."
	cd "$SRCDIR" || fatal "Cannot cd into SRCDIR!"
	time env $env BATCH_DELETE_OLD_FILES=yes make delete-old delete-old-libs > "$this_outdir/delete-old.log" 2>&1 || fatal "make delete-old delete-old-libs failed"

	echo "====> Gathering file lists..."
	cd "$DESTDIR" || fatal "Cannot cd into DESTDIR!"
	find -ds . | cut -b 2- > "$this_outdir/list.afterdeleteold"

	echo "====> Calculating leftovers..."
	diff -u "$this_outdir/list.all" "$this_outdir/list.afterdeleteold" | grep '^[+-][^+-]' > "$this_outdir/leftovers"

	mv "$this_outdir/leftovers" "$this_outdir/leftovers.tmp"
	for whitelist in $knobs; do
		if [ -e "$OFCDIR/whitelists/$whitelist" ]; then
			echo "=====> Applying whitelist for $whitelist..."
			sed -e '/^#/ d; s|^[^/]|/&|; s|^|+|; p' < $OFCDIR/whitelists/$whitelist >> "$this_outdir/leftovers.tmp"
		fi
	done
	sort < "$this_outdir/leftovers.tmp" | uniq -u > "$this_outdir/leftovers"

	# XXX: this lacks automatic placement of OLD_DIRS+= - dirs will be listed as OLD_FILES+=
	# XXX: would also be nice to autowrap files in share/lib32 with
	#      .if ${TARGET_ARCH} == "amd64" || ${TARGET_ARCH} == "powerpc64"
	cat $this_outdir/leftovers | sed -e 's|^+/|OLD_FILES+=|; s|^-/|# This should be removed from list: |; /\.so\.[0-9]/ s|^OLD_FILES|OLD_LIBS|' > "$this_outdir/makecode"

	[ -s "$this_outdir/leftovers" ] && (
		echo "Leftovers found for $knob :("
		echo "See"
		echo; echo "$this_outdir/leftovers"; echo
		echo "for the list of leftovers"
		echo "(+ = leftovers, - = files erroneously deleted)"
		echo "Also see"
		echo; echo "$this_outdir/makecode"; echo
		echo "as a template for adding to OptionalObsoleteFiles.inc"
	)

	echo "====> Cleaning up..."
	forced_rmdir "$DESTDIR"
done

if [ -n "$clean" ]; then
	forced_rmdir "$TMPDIR"
fi
