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
#	Persistent L2ARC with an encrypted ZFS file system succeeds
#
# STRATEGY:
#	1. Create pool with a cache device.
#	2. Create a an encrypted ZFS file system.
#	3. Create a random file in the encyrpted file system and random
#		read for 30 sec.
#	4. Export pool.
#	5. Read the amount of log blocks written from the header of the
#		L2ARC device.
#	5. Import pool.
#	6. Mount the encypted ZFS file system.
#	7. Read the amount of log blocks rebuild in arcstats and compare to
#		(5).
#	8. Read the file written in (2) and check if l2_hits in
#		/proc/spl/kstat/zfs/arcstats increased.
#	9. Check if the labels of the L2ARC device are intact.
#
#	* We can predict the minimum bytes of L2ARC restored if we subtract
#	from the effective size of the cache device the bytes l2arc_evict()
#	evicts:
#	l2: L2ARC device size - VDEV_LABEL_START_SIZE - l2ad_dev_hdr_asize
#	wr_sz: l2arc_write_max + l2arc_write_boost (worst case)
#	blk_overhead: wr_sz / SPA_MINBLOCKSIZE / (l2 / SPA_MAXBLOCKSIZE) *
#		sizeof (l2arc_log_blk_phys_t)
#	min restored size: l2 - 2 * (wr_sz + blk_overhead)
#				^
#				when l2ad_hand approaches l2ad_end
#

verify_runnable "global"

log_assert "Persistent L2ARC with an encrypted ZFS file system succeeds."

function cleanup
{
	if poolexists $TESTPOOL ; then
		destroy_pool $TESTPOOL
	fi

	log_must set_tunable32 l2arc_noprefetch $noprefetch
	log_must set_tunable32 l2arc_rebuild_blocks_min_size \
		$rebuild_blocks_min_size
}
log_onexit cleanup

# l2arc_noprefetch is set to 0 to let L2ARC handle prefetches
typeset noprefetch=$(get_tunable l2arc_noprefetch)
typeset rebuild_blocks_min_size=$(get_tunable l2arc_rebuild_blocks_min_size)
log_must set_tunable32 l2arc_noprefetch 0
log_must set_tunable32 l2arc_rebuild_blocks_min_size 0

typeset fill_mb=800
typeset cache_sz=$(( floor($fill_mb / 2) ))
export FILE_SIZE=$(( floor($fill_mb / $NUMJOBS) ))M

log_must truncate -s ${cache_sz}M $VDEV_CACHE

log_must zpool create -f $TESTPOOL $VDEV \
	cache $VDEV_CACHE

log_must eval "echo $PASSPHRASE | zfs create -o encryption=on" \
	"-o keyformat=passphrase $TESTPOOL/$TESTFS1"

log_must fio $FIO_SCRIPTS/mkfiles.fio
log_must fio $FIO_SCRIPTS/random_reads.fio

log_must zpool export $TESTPOOL

typeset l2_dh_log_blk=$(zdb -l $VDEV_CACHE | grep log_blk_count | \
	awk '{print $2}')

typeset l2_rebuild_log_blk_start=$(grep l2_rebuild_log_blks /proc/spl/kstat/zfs/arcstats \
	| awk '{print $3}')

log_must zpool import -d $VDIR $TESTPOOL
log_must eval "echo $PASSPHRASE | zfs mount -l $TESTPOOL/$TESTFS1"

typeset l2_hits_start=$(grep l2_hits /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

export RUNTIME=10
log_must fio $FIO_SCRIPTS/random_reads.fio

typeset l2_hits_end=$(grep l2_hits /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

typeset l2_rebuild_log_blk_end=$(grep l2_rebuild_log_blks /proc/spl/kstat/zfs/arcstats \
	| awk '{print $3}')

log_must test $l2_dh_log_blk -eq $(( $l2_rebuild_log_blk_end - $l2_rebuild_log_blk_start ))

log_must test $l2_hits_end -gt $l2_hits_start

log_must zdb -lq $VDEV_CACHE

log_must zpool destroy -f $TESTPOOL

log_pass "Persistent L2ARC with an encrypted ZFS file system succeeds."
