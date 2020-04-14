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
#	4. Randomly read the previous written file long enough for the
#		L2ARC vdev to be filled and overwritten.
#	5. Verify trim IOs of the expected type were issued for the pool.
#

verify_runnable "global"

log_assert "Auto trim of L2ARC succeeds."

function cleanup
{
	if poolexists $TESTPOOL; then
		destroy_pool $TESTPOOL
	fi

	log_must rm -f $VDEVS
}
log_onexit cleanup

# The cache device $TRIM_VDEV2 has to be small enough, so that
# dev->l2ad_hand loops around and dev->l2ad_first=0. Otherwise 
# l2arc_evict() exits before evicting/trimming.
VDEVS="$TRIM_VDEV1 $TRIM_VDEV2"
log_must truncate -s $((MINVDEVSIZE)) $TRIM_VDEV2
log_must truncate -s $((4 * MINVDEVSIZE)) $TRIM_VDEV1
log_must zpool create -f $TESTPOOL $TRIM_VDEV1 cache $TRIM_VDEV2
log_must zpool set autotrim=on $TESTPOOL

typeset fill_mb=$(( floor(2 * MINVDEVSIZE) ))
export DIRECTORY=/$TESTPOOL
export NUMJOBS=1
export FILE_SIZE=${fill_mb}
export PERF_RANDSEED=1234
export PERF_COMPPERCENT=66
export PERF_COMPCHUNK=0
export RUNTIME=30
export BLOCKSIZE=128K
export SYNC_TYPE=0
export DIRECT=1

# Write to the pool.
log_must fio $FIO_SCRIPTS/mkfiles.fio

# Read randomly from the pool to fill L2ARC.
export RUNTIME=1

typeset do_once=true
while $do_once || [[ $l2_size1 -le $l2_size2 ]]; do
	typeset l2_size1=$(get_arcstat l2_size)
	log_must fio $FIO_SCRIPTS/random_reads.fio
	typeset l2_size2=$(get_arcstat l2_size)
	do_once=false
done

verify_trim_io $TESTPOOL "ind" 10 $TRIM_VDEV2

log_must zpool destroy $TESTPOOL
log_must rm -f $VDEVS

log_pass "Auto trim of L2ARC succeeds."
