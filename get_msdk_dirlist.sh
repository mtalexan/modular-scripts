#!/bin/bash

MSDK_DIRLIST=()

mapfile -t MSDK_DIRLIST < <(find ${MSDK_BASEDIR} -maxdepth 1 -mindepth 1 \( -type d -o -type l \) | sed -e "s@${MSDK_BASEDIR}/@@g")

echo "${MSDK_DIRLIST[@]}"
