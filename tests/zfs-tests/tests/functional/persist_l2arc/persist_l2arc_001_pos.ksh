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

. $STF_SUITE/tests/functional/persist_l2arc/persist_l2arc.cfg
. $STF_SUITE/tests/functional/persist_l2arc/persist_l2arc.kshlib

#
# DESCRIPTION:
#	Persistent L2ARC with an unencrypted ZFS file system succeeds.
#
# STRATEGY:
#	1. Create pool with a cache device.
#	2. Create a random file in that pool and random read for 30 sec.
#	3. Export pool.
#	4. Import pool.
#	5. Check in zpool iostat if the cache device has space allocated.
#

verify_runnable "global"

log_assert "Persistent L2ARC with an unencrypted ZFS file system succeeds."
log_onexit cleanup

log_must zpool create $TESTPOOL $VDEV \
	cache $VDEV_CACHE

log_must fio --ioengine=libaio --direct=1 --name=test --bs=2M --size=800M \
	--readwrite=randread --runtime=30 --time_based --iodepth=64 \
	--directory="/$TESTPOOL"

for i in {1..100}; do
	log_must zpool export $TESTPOOL
	log_must zpool import -d $VDIR $TESTPOOL
	log_must test "$(zpool iostat -Hpv $TESTPOOL $VDEV_CACHE | awk '{print $2}')" -gt 80000000
done

log_must zpool destroy -f $TESTPOOL

log_assert "Persistent L2ARC with an unencrypted ZFS file system succeeds."
