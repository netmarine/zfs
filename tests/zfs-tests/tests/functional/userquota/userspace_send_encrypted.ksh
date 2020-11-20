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
# Sending raw encrypted datasets back to the source dataset succeeds.
#
#
# STRATEGY:
# 1. Create encrypted source dataset and base snapshot
# 2. Create an additional snapshot (s1)
# 3. Unmount the source dataset
# 4. Raw send the base snapshot to a new target dataset
# 5. Raw send incrementally the s1 snapshot to the new target dataset
# 6. Mount both source and target datasets
# 7. Verify encrypted datasets support 'zfs userspace' and 'zfs groupspace'
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

log_assert "Sending raw encrypted datasets back to the source dataset succeeds."

# Setup
truncate -s $SPA_MINDEVSIZE $FILEDEV
log_must zpool create $opts -o feature@encryption=enabled $POOLNAME \
	$FILEDEV

# Create encrypted source dataset
log_must eval "echo 'password' | zfs create -o encryption=on" \
	"-o keyformat=passphrase -o keylocation=prompt " \
	"$ENC_SOURCE"

# Snapshot, raw send to new dataset
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

#  Mount encrypted datasets and verify they support 'zfs userspace' and
# 'zfs groupspace'
log_must zfs mount $ENC_SOURCE
log_must eval "echo password | zfs load-key $ENC_TARGET"
log_must zfs mount $ENC_TARGET

log_must zfs userspace $ENC_SOURCE
log_must zfs groupspace $ENC_SOURCE
log_must zfs userspace $ENC_TARGET
log_must zfs groupspace $ENC_TARGET

# Cleanup
cleanup

log_pass "Sending raw encrypted datasets back to the source dataset succeeds."
