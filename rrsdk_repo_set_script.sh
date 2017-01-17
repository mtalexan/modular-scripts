#!/bin/bash

BASEDIR=${HOME}/rrsdk_code_repos
ERROR_RET=
PERFECT_MATCH=
MATCH_DIRS=()
SCRIPT_DIR=${LOCAL_REPOS_DIR}
SCRIPT_NAME=set_rrsdk.sh
MSDK_SCRIPT_NAME=set_msdk.sh

if [ -u $1 ] ; then
    #strip the DEVDIR down to the directory under $BASEDIR only
    CURRENT_DIR=$(echo $DEVDIR | sed "s@$BASEDIR/\(.*\)@\1@")
    echo "Current: $CURRENT_DIR"
    echo "Available: "
    echo "----------"
    lrr
    return 1
    exit 1 #in case we're called directly as a script
elif [ $1 == "help" ] ; then
    echo "USAGE: (source|.) $0 [(<string> | (grep|-) <regex> | (glob|.) <glob>)]"
    echo
    echo "    Sets the rrsdk repo instance selected as the one to be used for builds."
    echo "    If multiple matches are found or no arguments are given, the available"
    echo "    options will be listed instead."
    echo
    return 1
    exit 1 #in case we're called directly as a script
fi

source ${LOCAL_REPOS_DIR}/get_dir_match.incl

if [ ! -z "$ERROR_RET" ] ; then
    if [ $ERROR_RET -eq 2 ] ; then
        #provided search terms, but nothing matched
        echo 1>&2 "No matches found!!"
        return 2
        exit 2 #in case we're called directly as a script
    elif [ $ERROR_RET -eq 1 ] ; then
        #badly formatted arguments
        echo 1>&2 "Invalid arguments!"
        return 1
        exit 1 #in case we're called directly as a script
    fi
fi

# Didn't get a perfect match to a single directory?
if [ -z "$PERFECT_MATCH" ] ; then
    echo 1>&2 "Multiple matches found: "
    echo 1>&2 "-----------------------"
    # print each array entry on its own line
    printf '%s\n' "${MATCH_DIRS[@]}" 1>&2
    return 1
    exit 1 #in case we're called directly as a script
fi

echo "Setting to ${BASEDIR}/${PERFECT_MATCH}"

# Put the command to correctly setup the selected rrsdk repo path into a separate script
# so it can be run from the .bashrc at session start and give a consistent session setup

echo "export DEVDIR=${BASEDIR}/${PERFECT_MATCH}" > $SCRIPT_DIR/$SCRIPT_NAME
chmod +x $SCRIPT_DIR/$SCRIPT_NAME
source $SCRIPT_DIR/$SCRIPT_NAME

# space separated list of sub-directories in $DEVDIR that need to have all symbolic links directly contained
# in them removed
DIRS_TO_CLEAN="myapps/ksi-dmapp myapps/ksi-sharedlibs"

for dir in $DIRS_TO_CLEAN ; do
    # make sure the directory exists
    if [ -e ${DEVDIR}/${dir} ] ; then
        MODULAR_LINKS_TO_CHANGE=$(find ${DEVDIR}/${dir} -maxdepth 1 -type l)
        # turn it into a space separated list
        MODULAR_LINKS_TO_CHANGE=$( echo $MODULAR_LINKS_TO_CHANGE )
        # make sure there were actually results
        if [[ -n $MODULAR_LINKS_TO_CHANGE ]] ; then
            # remove all the link files
            rm $MODULAR_LINKS_TO_CHANGE
        fi
    fi
done

OLD_DIR=`pwd`
# Reset the path that was originally updated for the old RRSDK environment path
export PATH=$ORIG_PATH
# Go to the new rrsdk and run a make env so the environment is correctly setup
cd $DEVDIR
if [ $? -ne 0 ] ; then
    return 1
    exit 1 #in case we're called directly as a script
fi
`make env`

cd $OLD_DIR

# Change the link to point to the current modular directory file if it's actually a link (but only the new one)
if [ -h $DEVDIR/ksipn.mk ] ; then
    rm $DEVDIR/ksipn.mk
    ln -s $MODULAR_REPO_PATH/ksipn.mk $DEVDIR/ksipn.mk
fi

#make sure there isn't an MSDK script to confuse everything on the next environment load
rm $SCRIPT_DIR/$MSDK_SCRIPT_NAME

# if we're currently in the base dir or a sub-directory, move to the new rrsdk directory
# to avoid confusion with still being in the old one that's no longer setup
if [[ "$(pwd)" == *"$BASEDIR"* ]]; then
    # move to the new directory instead of the old one
    cd $DEVDIR
fi
