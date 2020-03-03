/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2019 Lawrence Livermore National Security, LLC.
 */

#ifndef _SYS_VDEV_TRIM_H
#define	_SYS_VDEV_TRIM_H

#include <sys/spa.h>
#include <sys/range_tree.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * The trim_args are a control structure which describe how a leaf vdev
 * should be trimmed.  The core elements are the vdev, the metaslab being
 * trimmed and a range tree containing the extents to TRIM.  All provided
 * ranges must be within the metaslab.
 */
typedef struct trim_args {
	/*
	 * These fields are set by the caller of vdev_trim_ranges().
	 */
	vdev_t		*trim_vdev;		/* Leaf vdev to TRIM */
	metaslab_t	*trim_msp;		/* Disabled metaslab */
	range_tree_t	*trim_tree;		/* TRIM ranges (in metaslab) */
	trim_type_t	trim_type;		/* Manual or auto TRIM */
	uint64_t	trim_extent_bytes_max;	/* Maximum TRIM I/O size */
	uint64_t	trim_extent_bytes_min;	/* Minimum TRIM I/O size */
	enum trim_flag	trim_flags;		/* TRIM flags (secure) */

	/*
	 * These fields are updated by vdev_trim_ranges().
	 */
	hrtime_t	trim_start_time;	/* Start time */
	uint64_t	trim_bytes_done;	/* Bytes trimmed */
} trim_args_t;

extern unsigned int zfs_trim_metaslab_skip;
extern unsigned int zfs_trim_extent_bytes_max;
extern unsigned int zfs_trim_extent_bytes_min;

extern void vdev_trim(vdev_t *vd, uint64_t rate, boolean_t partial,
    boolean_t secure);
extern void vdev_trim_stop(vdev_t *vd, vdev_trim_state_t tgt, list_t *vd_list);
extern void vdev_trim_stop_all(vdev_t *vd, vdev_trim_state_t tgt_state);
extern void vdev_trim_stop_wait(spa_t *spa, list_t *vd_list);
extern void vdev_trim_restart(vdev_t *vd);
extern void vdev_autotrim(spa_t *spa);
extern void vdev_autotrim_stop_all(spa_t *spa);
extern void vdev_autotrim_stop_wait(vdev_t *vd);
extern void vdev_autotrim_restart(spa_t *spa);
extern int vdev_trim_ranges(trim_args_t *ta);

#ifdef	__cplusplus
}
#endif

#endif	/* _SYS_VDEV_TRIM_H */
