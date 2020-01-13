#!/bin/ksh -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
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
export DIRECTORY=/$TESTPOOL
export FILE_SIZE=${fill_mb}M
export NUMJOBS=1
export RANDSEED=1234
export COMPPERCENT=40
export COMPCHUNK=512
export RUNTIME=30
export BLOCKSIZE=128K
export SYNC_TYPE=0
export DIRECT=1

log_must truncate -s ${cache_sz}M $VDEV_CACHE

log_must zpool create -f $TESTPOOL $VDEV \
	cache $VDEV_CACHE

log_must eval "echo $PASSPHRASE | zfs create -o encryption=on" \
	"-o keyformat=passphrase $TESTPOOL/$TESTFS1"

log_must fio $FIO_SCRIPTS/mkfiles.fio
log_must fio $FIO_SCRIPTS/random_reads.fio

log_must zpool export $TESTPOOL

typeset log_blk_start=$(grep l2_log_blk_writes /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

log_must zpool import -d $VDIR $TESTPOOL
log_must eval "echo $PASSPHRASE | zfs mount -l $TESTPOOL/$TESTFS1"

typeset log_blk_end=$(grep l2_log_blk_writes /proc/spl/kstat/zfs/arcstats | \
	awk '{print $3}')

log_must test $log_blk_start -eq $log_blk_end

log_must zpool destroy -f $TESTPOOL

log_pass "Persistent L2ARC restores all written log blocks with encryption."
