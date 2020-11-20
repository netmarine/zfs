#!/bin/ksh -p
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#

#
# Copyright 2020, George Amanakis <gamanakis@gmail.com>. All rights reserved.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/userquota/userquota_common.kshlib

#
# DESCRIPTION:
# XXX
# 'zfs userspace' and 'zfs groupspace' can be used on encrypted datasets
#
#
# STRATEGY:
# XXX
# 1. Create both un-encrypted and encrypted datasets
# 2. Receive un-encrypted dataset in encrypted hierarchy
# 3. Verify encrypted datasets support 'zfs userspace' and 'zfs groupspace'
#

function cleanup
{
	destroy_pool $POOLNAME
	rm -f $FILEDEV
}

function log_must_unsupported
{
	log_must_retry "unsupported" 3 "$@"
	(( $? != 0 )) && log_fail
}

log_onexit cleanup

FILEDEV="$TEST_BASE_DIR/userspace_encrypted"
POOLNAME="testpool$$"
ENC_SOURCE="$POOLNAME/source"
ENC_TARGET="$POOLNAME/target"

# XXX
log_assert "'zfs user/groupspace' should work on encrypted datasets"

# Setup
truncate -s $SPA_MINDEVSIZE $FILEDEV
log_must zpool create $opts -o feature@encryption=enabled $POOLNAME \
	$FILEDEV

# 1. Create encrypted dataset
log_must eval "echo 'password' | zfs create -o encryption=on" \
	"-o keyformat=passphrase -o keylocation=prompt " \
	"$ENC_SOURCE"

# 2. Receive encrypted dataset in encrypted hierarchy
log_must zfs snap $ENC_SOURCE@base
log_must zfs snap $ENC_SOURCE@s1
log_must zfs umount $ENC_SOURCE
log_must eval "zfs send -w $ENC_SOURCE@base | zfs recv " \
	"$ENC_TARGET"

log_must eval "zfs send -w -i @base $ENC_SOURCE@s1 | zfs recv " \
	"$ENC_TARGET"

log_must zfs destroy $ENC_SOURCE@s1
log_must eval "zfs send -w -i @base $ENC_TARGET@s1 | zfs recv " \
	"$ENC_SOURCE"

log_must zfs mount $ENC_SOURCE
log_must eval "echo password | zfs load-key $ENC_TARGET"
log_must zfs mount $ENC_TARGET

# 3. Verify encrypted datasets support 'zfs userspace' and
# 'zfs groupspace'
log_must zfs userspace $ENC_SOURCE
log_must zfs groupspace $ENC_SOURCE
log_must zfs userspace $ENC_TARGET
log_must zfs groupspace $ENC_TARGET

# Cleanup
cleanup

log_pass "'zfs user/groupspace' works on encrypted datasets"
