#!/bin/bash

# Get the clone datasets, and the dataset holding the clone datasets.  Remove the dataset holding the
# clone datasets from the list, and strip the dataset holding the clone datasets from all the names.

CLONE_LIST=()

mapfile -t CLONE_LIST < <(sudo zfs list -r -d 1 ${BASE_CLONE_ZPOOL} 2>/dev/null | awk '{if(NR>1)print $1}' | grep -v "^${BASE_CLONE_ZPOOL}$" | sed -e "s|${BASE_CLONE_ZPOOL}/||g")

echo "${CLONE_LIST[@]}"
