#!/bin/bash


REAL_CLONE_NAME=$(sudo zfs list -r ${BASE_CLONE_ZPOOL} 2>/dev/null | awk '{if(NR>1)print $1}' | grep "${1}$" | head -n1)

# gets the "origin" property, which points to the snapshot that it was created from
# Have to do this before the possible clone promotion below.
SNAPSHOT_USED=$(sudo zfs get origin ${REAL_CLONE_NAME} 2>/dev/null | awk '{if(NR>1)print $3}' | sed -e "s|${BASE_ZPOOL}/||g")
echo "${SNAPSHOT_USED}"
