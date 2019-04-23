#!/bin/bash
# Tries to locate matches and process the commands from the command-line
# Only prints to stderr unless it successfully handles the aruguments.
#
# On success, the exit code is 0 and the only output on stdout is the full path to the workspace
# On error, errors are printed to stderr and exit code 1 is returned

# setup our variables that might be set by arg parsing
SUBDIR=
ERROR_RET=
PERFECT_MATCH=
MATCH_DIRS=()

while [ ! -z "$1" ] ; do
    case "$1" in
        "/")
            # a "/" indicates an argument follows that's the subdirectory to navigate to if we
            # change directories
            SUBDIR=$2
            shift
            shift
            ;;
        *)
            # Let the match parsing handle it
            source ${LOCAL_REPOS_DIR}/get_dir_match.incl
            ;;
    esac
done

if [ ! -z "$ERROR_RET" ] ; then
    if [ $ERROR_RET -eq 2 ] ; then
        #provided search terms, but nothing matched
        echo 1>&2 "No matches found"
        exit 2
    elif [ $ERROR_RET -eq 1 ] ; then
        #badly formatted arguments
        echo 1>&2 "Invalid arguments"
        exit 1
    fi
fi

FULL_DIR=

# Construct the full path to the specific directory if we can
if [ ${#MATCH_DIRS[@]} -lt 1 ] ; then
    #found no matches, or had no arguments about matches
    if [ -z "$MSDK_ROOT_DIR" ] ; then
        echo 1>&2 'MSDK_ROOT_DIR not set, cannot default to $MSDK_ROOT_DIR'
        exit 1
    else
        FULL_DIR=${MSDK_ROOT_DIR}/${SUBDIR}
    fi
elif [ ! -z "$PERFECT_MATCH" ] ; then
    #only one match for our search terms, or had a perfect match on a non-glob search term
    FULL_DIR=${MSDK_BASEDIR}/${PERFECT_MATCH}/${SUBDIR}
fi

#have a full path to a specific directory?
if [ ! -z "$FULL_DIR" ] ; then
    echo ${FULL_DIR}
    exit 0
else
    echo 1>&2 "Multiple matches found: "
    echo 1>&2 "-----------------------"
    # print each array entry on its own line
    printf '%s\n' "${MATCH_DIRS[@]}" 1>&2
    exit 1
fi
