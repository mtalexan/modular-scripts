#!/bin/bash

shopt -s nullglob
shopt -s nocasematch

if [ -u $1 ] ; then
    ls -1 ${MSDK_BASEDIR}
    exit 0
elif [ $1 == "help" ] ; then
    echo "USAGE: $0 [(<string> | (grep|-) <regex> | (glob|.) <glob>)]" 1>&2
    echo 1>&2
    echo "    Lists the possible options for modular repo instances that can be selected" 1>&2
    echo 1>&2
    exit 1
fi

MATCH_MSDK=()

# determine whether argument 1 was just a case sensitive string we want to find,
# or whether it was specifying whether we want to use argument 2 as a glob or
# grep search
case "$1" in
    "grep" | "-" )
        MATCH_MSDK=$(ls -d -1 * | grep -e "$2") ;;
    "glob" | "." )
        MATCH_MSDK=$(ls -d ${2})  ;;
    *)
        MATCH_MSDK=$(ls -d *${1}*)
esac

# one per line
printf '%s\n' "${MATCH_MSDK[@]}"
