#!/bin/bash

# Get the clone datasets, and the dataset holding the clone datasets.  Remove the dataset holding the
# clone datasets from the list.
CLONE_LIST=$(sudo zfs list -r -d 1 ${BASE_CLONE_ZPOOL} 2>/dev/null | awk '{if(NR>1)print $1}' | grep -v "^${BASE_CLONE_ZPOOL}$")

SNAP_LIST=()
SNAP=
# Get the snapshots for our base clones
for D in ${CLONE_LIST}; do
    SNAPS=$(sudo zfs list -r ${D} -t snapshot 2>/dev/null | awk '{if(NR>1)print $1}' | sed -e "s|${BASE_CLONE_ZPOOL}/||g")
    if [ -n "${SNAPS}" ] ; then
        for S in ${SNAPS} ; do
            SNAP_LIST+=("${S}")
        done
    fi
done

echo "${SNAP_LIST[@]}"
