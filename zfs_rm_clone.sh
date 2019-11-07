#!/bin/bash

TOP_ZPOOL=${TOP_ZPOOL:-phyhomedir/home} # this must already exist
# The pool base datasets are created in
BASE_ZPOOL=${TOP_ZPOOL}/msdk
# The pool ZFS clones are created in
BASE_CLONE_ZPOOL=${BASE_ZPOOL}/clones

CMagentaForeground="\\033[35m"
CBold="\\033[1m"
CNone="\\033[0m"

print_usage()
{
    echo "USAGE"
    echo "  $0 name-of-clone [name-of-clone2 ...]"
    echo ""
    echo " Removes a ZFS clone.  Cleans up by checking to see if the snapshot it's based on is now unused"
    echo " and needs removal also. If the snapshot gets removed, checks to see if the dataset the snapshot"
    echo " is based on is now unreferenced, and will remove that too if it is."
    echo " It handles the case where a ZFS clone has its own snapshots that may have their own clones, and"
    echo " will promote one of the child clones if avaiable.  It will remove any other snapshots without"
    echo " child clones."
    echo ""
    echo "ARGUMENTS"
    echo ""
    echo "  name-of-clone"
    echo "   Name of the ZFS clone to clean up.  Can be repeated to be run for multiple ZFS clones."
    echo "   The name can be the name within the containing dataset, or the entire name of the ZFS clone."
    echo ""
}

OPTS=$(getopt -n "$(basename $0)" --options h --longoptions help -- "$@")
if [ $? -ne 0 ]
then
    echo "ERROR: Unable to parse arguments"
    print_usage
    exit 1
fi

eval set -- "$OPTS"

NAMES=()
FREE_ARGS=false

# we don't allow empty double quote arguments so don't worry about that corner case here
while [ -n "$1" ]
do
    case $1 in
        -h | --help )
            print_usage
            exit 0
            ;;
        -- )
            FREE_ARGS=true
            shift
            ;;
        * )
            if ${FREE_ARGS}
            then
                NAMES+=("$1")
                shift
            else
                echo "ERROR: Unrecognized argument \"$1\""
                print_usage
                exit 1
            fi
            ;;
    esac
done

if [ ${#NAMES[@]} -eq 0 ]
then
    echo "ERROR: Required argument missing"
    print_usage
    exit 1
fi

for N in ${NAMES[@]}
do
    echo -e "${CMagentaForeground}${CBold}""Removing ZFS clone: $N""${CNone}"
    SNAPSHOT_USED=
    DATASET_USED=

    # Get the clone matching the name
    REAL_CLONE_NAME=$(sudo zfs list -r ${BASE_CLONE_ZPOOL} 2>/dev/null | awk '{if(NR>1)print $1}' | grep "${N}$" | head -n1)

    # Does the clone matching that name exist?
    if [ -z "${REAL_CLONE_NAME}" ] ; then
        echo "ERROR: ZFS clone doesn't exist"
    else

        # gets the "origin" property, which points to the snapshot that it was created from
        # Have to do this before the possible clone promotion below.
        SNAPSHOT_USED=$(sudo zfs get origin ${REAL_CLONE_NAME} 2>/dev/null | awk '{if(NR>1)print $3}')

        # Find any snapshots we have.
        SNAPSHOTS=()

        # If we have no snapshots, then it returns "no datasets available" without any column headings.
        # So look for a result with column headings and at least one entry, which means a minimum of 2 lines
        # in the response, and only query to build the list of snapshots if we have snapshots for the
        # clone.
        if [ $(sudo zfs list -r ${REAL_CLONE_NAME} -t snapshot 2>/dev/null | wc -l) -ge 2 ] ; then
            mapfile -t SNAPSHOTS < <(sudo zfs list -r ${REAL_CLONE_NAME} -t snapshot 2>/dev/null | awk '{if(NR>1)print $1}')
        fi

        for S in ${SNAPSHOTS[@]} ; do
            # get the first clone of the snapshot, if any (comma-separated list for the "clones" attribute)
            SNAP_CLONE_1=$(sudo zfs get clones ${S} 2>/dev/null | awk '{if(NR>1)print $3}'| cut -d ',' -f 1)
            # if no clones from the snapshot, it's set to "-" instead
            if [ "${SNAP_CLONE_1}" == "-" ] ; then
                #snapshot not being used by any clones, destroy it
                echo "Destroying: ${S}"
                sudo zfs destroy ${S} &>/dev/null
            else
                # has clones, so promote the first clone of the snapshot, which makes it a snapshot of
                # the promoted clone instead, and us a clone of that.
                echo "Promoting child clone that's still in use: ${SNAP_CLONE_1}"
                sudo zfs promote ${SNAP_CLONE_1} &>/dev/null
                SNAPSHOT_USED=
            fi
        done

        # all snapshots are either destroyed, or we've promoted a clone so we're the clone now.
        # SNAPSHOT_USED is either blank (if we did clone promotion), or is pointing to the snapshot
        # we were cloned from.

        # remove the clone
        echo "Destroying: ${REAL_CLONE_NAME}"
        sudo zfs destroy ${REAL_CLONE_NAME} &>/dev/null
    fi

    # If we didn't promote one of our zfs clones, we should know the snapshot we were generated from
    if [ -n "${SNAPSHOT_USED}" ] ; then
        # anyone else using this snapshot still?  Check the "clones" attribute to see.  Will return just "-"
        # if there's nothing
        if [ "$(sudo zfs get clones ${SNAPSHOT_USED} 2>/dev/null | awk '{if(NR>1)print $3}')" == "-" ] ; then
            # strip the @XXX off the end to get the base dataset
            DATASET_USED=$(echo "${SNAPSHOT_USED}" | sed -e 's/@.*$//g')

            #remove the snapshot
            echo "Snapshot no longer used, destroying: ${SNAPSHOT_USED}"
            sudo zfs destroy ${SNAPSHOT_USED} &>/dev/null
        else
            echo "Snapshot still in use: ${SNAPSHOT_USED}"
        fi
    fi

    if [ -n "${DATASET_USED}" ] ; then
        # Any other snapshots using the dataset?
        # Snapshots are only listed if we explicitly look for them, but if there aren't any then we'll
        # get "no datasets available" rather than a list of matches.  There are no column headings if
        # there are no matches though, so look for whether column headings were produced, which means
        # having at least 2 lines in the result
        if [ $(sudo zfs list -r ${DATASET_USED} -t snapshot 2>/dev/null | wc -l) -lt 2 ]  ; then
            echo "Dataset no longer used, destroying: ${DATASET_USED}"
            sudo zfs destroy ${DATASET_USED} &>/dev/null
        else
            echo "Dataset still in use: ${DATASET_USED}"
        fi
    fi
done


