#!/bin/bash

# Get the base datasets, and the dataset holding the base datasets.  Remove the dataset holding the
# base datasets and the dataset holding the clones from the list, and strip the dataset holding the
# base datasets from all the names.
BASE_CLONE_LIST=()

mapfile -t BASE_CLONE_LIST < <(sudo zfs list -r -d 1 ${BASE_ZPOOL} 2>/dev/null | awk '{if(NR>1)print $1}' | grep -v "${BASE_CLONE_ZPOOL}" | grep -v "^${BASE_ZPOOL}$" | sed -e "s|${BASE_ZPOOL}/||g")

echo "${BASE_CLONE_LIST[@]}"




