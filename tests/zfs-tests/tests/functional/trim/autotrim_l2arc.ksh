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

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/trim/trim.kshlib
. $STF_SUITE/tests/functional/trim/trim.cfg

#
# DESCRIPTION:
# 	Verify trimming of L2ARC
#
# STRATEGY:
#	1. Create a pool on file vdevs to trim.
#	2. Set 'autotrim=on' on pool.
#	3. Fill the pool with a file larger than the L2ARC vdev.
#	4. Export and re-import the pool to stop trimming on main vdev.
#	5. Record autotrim_extents_written.
#	6. Randomly read the previous written file long enough for the
#		L2ARC vdev to be filled and overwritten.
#	7. Verify that autotrim_extents_written has increased.

verify_runnable "global"

log_assert "Set 'autotrim=on' verify L2ARC was trimmed"

function cleanup
{
	if poolexists $TESTPOOL; then
		destroy_pool $TESTPOOL
	fi

	log_must rm -f $TRIM_VDEVS

	log_must set_tunable64 zfs_trim_extent_bytes_min $trim_extent_bytes_min
	log_must set_tunable64 zfs_trim_txg_batch $trim_txg_batch
	log_must set_tunable64 zfs_vdev_min_ms_count $vdev_min_ms_count
}
log_onexit cleanup

# Minimum trim size is decreased to verify all trim sizes.
typeset trim_extent_bytes_min=$(get_tunable zfs_trim_extent_bytes_min)
log_must set_tunable64 zfs_trim_extent_bytes_min 4096

# Reduced zfs_trim_txg_batch to make trimming more frequent.
typeset trim_txg_batch=$(get_tunable zfs_trim_txg_batch)
log_must set_tunable64 zfs_trim_txg_batch 8

# Increased metaslabs to better simulate larger more realistic devices.
typeset vdev_min_ms_count=$(get_tunable zfs_vdev_min_ms_count)
log_must set_tunable64 zfs_vdev_min_ms_count 32

# The cache device $TRIM_VDEV2 has to be small enough, so that
# dev->l2ad_hand loops around and dev->l2ad_first=0. Otherwise 
# l2arc_evict() exits before evicting/trimming.
VDEVS="$TRIM_VDEV1 $TRIM_VDEV2"
log_must truncate -s $((MINVDEVSIZE)) $TRIM_VDEV2
log_must truncate -s $((4 * MINVDEVSIZE)) $TRIM_VDEV1
log_must zpool create -f $TESTPOOL $TRIM_VDEV1 cache $TRIM_VDEV2
log_must zpool set autotrim=on $TESTPOOL

typeset fill_mb=$(( floor(2 * MINVDEVSIZE) ))

# Write to the pool.
log_must fio --ioengine=libaio --direct=1 --name=test --bs=2M \
       --size=$fill_mb --readwrite=randread --runtime=1 --time_based \
       --iodepth=64 --directory=/$TESTPOOL

# Export and re-import the pool to stop possible trimming on $TRIM_VDEV1.
log_must zpool export $TESTPOOL
log_must zpool import -d $TRIM_DIR $TESTPOOL

typeset l2arc_trim_start=$(grep autotrim_extents_written \
	/proc/spl/kstat/zfs/$TESTPOOL/iostats | \
	awk '{print $3}')

# Read randomly from the pool to fill L2ARC.
log_must fio --ioengine=libaio --direct=1 --name=test --bs=2M \
       --size=$fill_mb --readwrite=randread --runtime=10 --time_based \
       --iodepth=64 --directory=/$TESTPOOL

typeset l2arc_trim_end=$(grep autotrim_extents_written \
	/proc/spl/kstat/zfs/$TESTPOOL/iostats | \
	awk '{print $3}')

log_must test $l2arc_trim_end -gt $l2arc_trim_start

log_must zpool destroy $TESTPOOL
log_must rm -f $VDEVS

log_pass "Auto trim of L2ARC succeeds."
