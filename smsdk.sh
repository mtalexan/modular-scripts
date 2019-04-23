#!/bin/bash
# Attempts to determine the new location to change to.
# All output is on stderr except for the file return from the script if successful
#
# On success, prints the name of the file that should be sourced to provide environment variable settings
# On failure, non-zero exit code and no stdout


ERROR_RET=
PERFECT_MATCH=
MATCH_DIRS=()
SCRIPT_DIR=${LOCAL_REPOS_DIR}
SCRIPT_NAME=set_msdk.sh

if [ -u $1 ] ; then
    #strip the MSDK_ROOT_DIR down to the directory under $MSDK_BASEDIR only
    CURRENT_DIR=$(echo $MSDK_ROOT_DIR | sed "s@${MSDK_BASEDIR}/@@g")
    echo "Current: $CURRENT_DIR" 1>&2
    echo "Available: " 1>&2
    echo "----------" 1>&2
    lmsdk
    exit 1
elif [ $1 == "help" ] ; then
    echo "USAGE: (source|.) $0 [(<string> | (grep|-) <regex> | (glob|.) <glob>)]" 1>&2
    echo >&2
    echo "    Sets the msdk repo instance selected as the one to be used for builds." 1>&2
    echo "    If multiple matches are found or no arguments are given, the available" 1>&2
    echo "    options will be listed instead." 1>&2
    echo 1>&2
    exit 1
fi

source ${LOCAL_REPOS_DIR}/get_dir_match.incl

if [ ! -z "$ERROR_RET" ] ; then
    if [ $ERROR_RET -eq 2 ] ; then
        #provided search terms, but nothing matched
        echo 1>&2 "No matches found!!"
        exit 2
    elif [ $ERROR_RET -eq 1 ] ; then
        #badly formatted arguments
        echo 1>&2 "Invalid arguments!"
        exit 1
    fi
fi

# Didn't get a perfect match to a single directory?
if [ -z "$PERFECT_MATCH" ] ; then
    echo 1>&2 "Multiple matches found: "
    echo 1>&2 "-----------------------"
    # print each array entry on its own line
    printf '%s\n' "${MATCH_DIRS[@]}" 1>&2
    exit 1
fi

echo "Setting to ${MSDK_BASEDIR}/${PERFECT_MATCH}" 1>&2

# Put the command to correctly setup the selected modularSDK repo path into a separate script
# so it can be run from the .bashrc at session start and give a consistent session setup

echo "export MSDK_ROOT_DIR=${MSDK_BASEDIR}/${PERFECT_MATCH}" > $SCRIPT_DIR/$SCRIPT_NAME
chmod +x $SCRIPT_DIR/$SCRIPT_NAME
source $SCRIPT_DIR/$SCRIPT_NAME

# space separated list of sub-directories in $MSDK_ROOT_DIR that need to have all symbolic links
#directly contained in them removed when changing modularSDK sandboxes
DIRS_TO_CLEAN=

for dir in $DIRS_TO_CLEAN ; do
    # make sure the directory exists
    if [ -e ${MSDK_ROOT_DIR}/${dir} ] ; then
        LINKS_TO_CHANGE=$(find ${MSDK_ROOT_DIR}/${dir} -maxdepth 1 -type l)
        # turn it into a space separated list
        LINKS_TO_CHANGE=$( echo $LINKS_TO_CHANGE )
        # make sure there were actually results
        if [[ -n $LINKS_TO_CHANGE ]] ; then
            # remove all the link files
            rm $LINKS_TO_CHANGE
        fi
    fi
done

# echo this so it can be used by the calling script
echo "$SCRIPT_DIR/$SCRIPT_NAME"

