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

#
# DESCRIPTION:
#	Persistent L2ARC fails as expected when l2arc_rebuild_enabled = 0
#
# STRATEGY:
#	1. Set l2arc_rebuild_enabled = 0
#	2. Create pool with a cache device.
#	3. Create a random file in that pool and random read for 30 sec.
#	4. Export pool.
#	5. Import pool.
#	6. Check in zpool iostat if the cache device has space allocated.
#	7. Read the file written in (2) and check if l2_hits in
#		/proc/spl/kstat/zfs/arcstats increased.
#

verify_runnable "global"

log_assert "Persistent L2ARC fails as expected when l2arc_rebuild_enabled = 0."

function cleanup
{
	if poolexists $TESTPOOL ; then
		destroy_pool $TESTPOOL
	fi

	log_must set_tunable32 l2arc_rebuild_enabled $rebuild_enabled
	log_must set_tunable32 l2arc_noprefetch $noprefetch
}
log_onexit cleanup

# l2arc_noprefetch is set to 0 to let L2ARC handle prefetches
typeset noprefetch=$(get_tunable l2arc_noprefetch)
log_must set_tunable32 l2arc_noprefetch 0

# disable L2ARC rebuild
typeset rebuild_enabled=$(get_tunable l2arc_rebuild_enabled)
log_must set_tunable32 l2arc_rebuild_enabled 0

log_must zpool create $TESTPOOL $VDEV \
	cache $VDEV_CACHE

log_must fio --ioengine=libaio --direct=1 --name=test --bs=2M --size=800M \
	--readwrite=randread --runtime=30 --time_based --iodepth=64 \
	--directory="/$TESTPOOL"

log_must zpool export $TESTPOOL
log_must zpool import -d $VDIR $TESTPOOL
log_mustnot test "$(zpool iostat -Hpv $TESTPOOL $VDEV_CACHE | awk '{print $2}')" -gt 80000000

log_must zpool destroy -f $TESTPOOL

log_assert "Persistent L2ARC fails as expected when l2arc_rebuild_enabled = 0."
