#!/bin/bash

BASEDIR=${HOME}/msdk_code_repos
ERROR_RET=
PERFECT_MATCH=
MATCH_DIRS=()
SCRIPT_DIR=${LOCAL_REPOS_DIR}
SCRIPT_NAME=set_msdk.sh
DEVDIR_SCRIPT_NAME=set_rrsdk.sh

if [ -u $1 ] ; then
    #strip the DEVDIR down to the directory under $BASEDIR only
    CURRENT_DIR=$(echo $MSDK_ROOT_DIR | sed "s@$BASEDIR/\(.*\)@\1@")
    echo "Current: $CURRENT_DIR"
    echo "Available: "
    echo "----------"
    lmsdk
    return 1
    exit 1 #in case we're called directly as a script
elif [ $1 == "help" ] ; then
    echo "USAGE: (source|.) $0 [(<string> | (grep|-) <regex> | (glob|.) <glob>)]"
    echo
    echo "    Sets the msdk repo instance selected as the one to be used for builds."
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
        exit 1 #in case we're called directly as a script
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

echo "export MSDK_ROOT_DIR=${BASEDIR}/${PERFECT_MATCH}" > $SCRIPT_DIR/$SCRIPT_NAME
chmod +x $SCRIPT_DIR/$SCRIPT_NAME
source $SCRIPT_DIR/$SCRIPT_NAME

# space separated list of sub-directories in $MSDK_ROOT_DIR that need to have all symbolic links
#directly contained in them removed
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

####### Don't update the links, we use the MSDK as self-contained sandboxes now
## Change the links to point to the current modular directory file if it's actually a link (but only the new one)
#if [ -h $MSDK_ROOT_DIR/modular ] && [ -n "$(readlink -e $MODULAR_REPO_PATH)" ] ; then
#    if [[ "$(readlink -e $MODULAR_REPO_PATH)" == *"$BASEDIR"* ]] ; then
#        #MODULAR_REPO_PATH was going to an internal for some other MSDK so don't use it
#        rm $MSDK_ROOT_DIR/sdk-apps/ksi-dmapp/src
#        ln -s $MSDK_ROOT_DIR/sdk-apps/ksi-dmapp/.src_repo $MSDK_ROOT_DIR/sdk-apps/ksi-dmapp/src
#    else
#        #MODULAR_REPO_PATH is probably pointint to a link, so update with the real underlying file
#        rm $MSDK_ROOT_DIR/sdk-apps/ksi-dmapp/src
#        ln -s $(readlink -e $MODULAR_REPO_PATH) $MSDK_ROOT_DIR/sdk-apps/ksi-dmapp/src
#    fi
#fi

########## Don't update the sdk link in the msdk, treat the msdk like it includes the sdk
##########
## Change the link to point to the current sdk directory file
#if [ -h $MSDK_ROOT_DIR/sdk ] && [ -n "$(readlink -e $DEVDIR)" ] ; then
#    #don't let an MSDK point to something in rrsdk
#    if [[ "$(readlink -e $DEVDIR)" == *"rrsdk"* ]] ; then
#        #default to the .sdk_repo folder in the MSDK
#        ln -sf $MSDK_ROOT_DIR/.sdk_repo $MSDK_ROOT_DIR/sdk
#    else
#        #DEVDIR is probably set to the symlink we're updating, so get it to point to the
#        #proper underlying file/folder
#        ln -sf $(readlink -e $DEVDIR) $MSDK_ROOT_DIR/sdk
#    fi
#fi

OLD_DIR=`pwd`
# Go to the new msdk and run a make env so the environment is correctly setup
cd $MSDK_ROOT_DIR
if [ $? -ne 0 ] ; then
    return 1
    exit 1 #in case we're called directly as a script
fi
`make env`

cd $OLD_DIR

#do this so DEVDIR gets reset based on our MSDK setting in the next environment load
echo "export DEVDIR=${DEVDIR}" > $SCRIPT_DIR/$DEVDIR_SCRIPT_NAME
chmod +x $SCRIPT_DIR/$DEVDIR_SCRIPT_NAME

# if we're currently in the base dir or a sub-directory, move to the new msdk directory
# to avoid confusion with still being in the old one that's no longer setup
if [[ "$(pwd)" == *"$BASEDIR"* ]]; then
    # move to the new directory instead of the old one
    cd $MSDK_ROOT_DIR
fi
