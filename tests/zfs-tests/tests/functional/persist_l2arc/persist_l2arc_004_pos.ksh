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

#
# DESCRIPTION:
#	Persistent L2ARC restores all written log blocks
#
# STRATEGY:
#	1. Create pool with a cache device.
#	2. Create a random file in that pool, smaller than the cache device
#		and random read for 30 sec.
#	3. Export pool.
#	4. Read amount of log blocks written.
#	5. Import pool.
#	6. Read amount of log blocks built.
#	7. Compare the two amounts
#	8. Check if the labels of the L2ARC device are intact.
#

verify_runnable "global"

log_assert "Persistent L2ARC restores all written log blocks."

function cleanup
{
	if poolexists $TESTPOOL ; then
		destroy_pool $TESTPOOL
	fi

	log_must set_tunable32 L2ARC_NOPREFETCH $noprefetch
}
log_onexit cleanup

# L2ARC_NOPREFETCH is set to 0 to let L2ARC handle prefetches
typeset noprefetch=$(get_tunable L2ARC_NOPREFETCH)
log_must set_tunable32 L2ARC_NOPREFETCH 0

typeset fill_mb=800
typeset cache_sz=$(( 2 * $fill_mb ))
export FILE_SIZE=$(( floor($fill_mb / $NUMJOBS) ))M

log_must truncate -s ${cache_sz}M $VDEV_CACHE

log_must zpool create -f $TESTPOOL $VDEV \
	cache $VDEV_CACHE

log_must fio $FIO_SCRIPTS/mkfiles.fio
log_must fio $FIO_SCRIPTS/random_reads.fio

log_must zpool export $TESTPOOL

typeset log_blk_start=$(grep l2_log_blk_writes /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

log_must zpool import -d $VDIR $TESTPOOL

typeset log_blk_end=$(grep l2_log_blk_writes /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

log_must test $log_blk_start -eq $log_blk_end

log_must zdb -lq $VDEV_CACHE

log_must zpool destroy -f $TESTPOOL

log_pass "Persistent L2ARC restores all written log blocks."
