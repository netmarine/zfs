#!/bin/ksh -p
#
# CDDL HEADER START
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
# CDDL HEADER END
#

#
# Copyright (c) 2020, George Amanakis. All rights reserved.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/persist_l2arc/persist_l2arc.cfg
. $STF_SUITE/tests/functional/cli_root/zfs_load-key/zfs_load-key_common.kshlib

#
# DESCRIPTION:
#	Persistent L2ARC restores all written log blocks with encryption
#
# STRATEGY:
#	1. Create pool with a cache device.
#	2. Create a an encrypted ZFS file system.
#	3. Create a random file in the entrypted file system,
#		smaller than the cache device, and random read for 30 sec.
#	4. Export pool.
#	5. Read amount of log blocks written.
#	6. Import pool.
#	7. Mount the encypted ZFS file system.
#	8. Read amount of log blocks built.
#	9. Compare the two amounts
#	10. Check if the labels of the L2ARC device are intact.
#

verify_runnable "global"

log_assert "Persistent L2ARC restores all written log blocks with encryption."

function cleanup
{
	if poolexists $TESTPOOL ; then
		destroy_pool $TESTPOOL
	fi

	log_must set_tunable32 l2arc_noprefetch $noprefetch
}
log_onexit cleanup

# l2arc_noprefetch is set to 0 to let L2ARC handle prefetches
typeset noprefetch=$(get_tunable l2arc_noprefetch)
log_must set_tunable32 l2arc_noprefetch 0

typeset fill_mb=800
typeset cache_sz=$(( 2 * $fill_mb ))
export FILE_SIZE=$(( floor($fill_mb / $NUMJOBS) ))M

log_must truncate -s ${cache_sz}M $VDEV_CACHE

typeset log_blk_start=$(grep l2_log_blk_writes /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

log_must zpool create -f $TESTPOOL $VDEV \
	cache $VDEV_CACHE

log_must eval "echo $PASSPHRASE | zfs create -o encryption=on" \
	"-o keyformat=passphrase $TESTPOOL/$TESTFS1"

log_must fio $FIO_SCRIPTS/mkfiles.fio
log_must fio $FIO_SCRIPTS/random_reads.fio

log_must zpool export $TESTPOOL

sleep 2

typeset log_blk_end=$(grep l2_log_blk_writes /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

typeset log_blk_rebuild_start=$(grep l2_rebuild_log_blks /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

log_must zpool import -d $VDIR $TESTPOOL
log_must eval "echo $PASSPHRASE | zfs mount -l $TESTPOOL/$TESTFS1"

sleep 2

typeset log_blk_rebuild_end=$(grep l2_rebuild_log_blks /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

log_must test $(( $log_blk_rebuild_end - $log_blk_rebuild_start )) -eq \
	$(( $log_blk_end - $log_blk_start ))

log_must zdb -lq $VDEV_CACHE

log_must zpool destroy -f $TESTPOOL

log_pass "Persistent L2ARC restores all written log blocks with encryption."
