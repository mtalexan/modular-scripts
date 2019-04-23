#!/bin/bash


# Get the base datasets, and the dataset holding the base datasets.  Remove the dataset holding the
# base datasets and the dataset holding the clones from the list.
BASE_CLONE_LIST=$(sudo zfs list -r -d 1 ${BASE_ZPOOL} 2>/dev/null | awk '{if(NR>1)print $1}' | grep -v "${BASE_CLONE_ZPOOL}" | grep -v "^${BASE_ZPOOL}$")

SNAP_LIST=()
SNAP=

# Get the snapshots for our base clones
for D in ${BASE_CLONE_LIST}; do
    SNAPS=$(sudo zfs list -r ${D} -t snapshot 2>/dev/null | awk '{if(NR>1)print $1}' | sed -e "s|${BASE_ZPOOL}/||g")
    if [ -n "${SNAPS}" ] ; then
        for S in ${SNAPS} ; do
            SNAP_LIST+=("${S}")
        done
    fi
done

echo "${SNAP_LIST[@]}"
