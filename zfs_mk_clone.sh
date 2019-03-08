#!/bin/bash

MSDK_BASEDIR=${HOME}/msdk_code_repos
TOP_ZPOOL=phyhomedir/home # this must already exist
# The pool to create git clones in that we'll create ZFS clones of.
# Will be auto-created as long as it's only 1 level deep from TOP_ZPOOL
BASE_ZPOOL=${TOP_ZPOOL}/msdk
# The pool to create ZFS clones in
# Will be auto-created as long as it's only 1 level deep from TOP_ZPOOL or BASE_ZPOOL
BASE_CLONE_ZPOOL=${BASE_ZPOOL}/clones

CMagentaForeground="\\033[35m"
CBold="\\033[1m"
CNone="\\033[0m"

print_usage()
{
    echo "USAGE"
    echo "  $0 name-of-source-dataset name-of-new-clone [name-of-new-clone2 ...]"
    echo ""
    echo " Creates a ZFS clone from an existing ZFS dataset given either a snapshot or raw dataset and"
    echo " one or more new names.  Assumes all new ZFS clones should have a mountpoint in ${MSDK_BASE_DIR}"
    echo ""
    echo "ARGUMENTS"
    echo "  name-of-source-dataset"
    echo "   The name of the source snapshot or dataset to create a copy of.  It will create a new snapshot"
    echo "   if a dataset is provided, or use the snapshot specified if provided directly.  The name provided"
    echo "   only has to match the dataset name (and snapshot name if specifying a snapshot)."
    echo "   e.g. for tank/home/msdk/clones/test-msdk@20190306123030 either the full name or just "
    echo "   \"test-msdk@20190306123030\" can be specified to re-use an existing snapshot, or just \"test-msdk\""
    echo "   can be used to automatically create a new snapshot from the dataset."
    echo ""
    echo "  name-of-clone"
    echo "   Name to create the clone under.  Standard syntax for git-fast-clone on this argument applies."
    echo "   Note that this can be a path to a folder as long as all intermediate paths already exist."
    echo "   Can be repeated for additional names of clones to also create.  When repeated for additional"
    echo "   repo clones, all will be zfs clones from the same snapshot."
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
SOURCE_DATASET=

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
                if [ -z "${SOURCE_DATASET}" ] ; then
                    SOURCE_DATASET="${1}"
                else
                    NAMES+=("$1")
                fi
                shift
            else
                echo "ERROR: Unrecognized argument \"$1\""
                print_usage
                exit 1
            fi
            ;;
    esac
done

# Need at least 1 value for the destination
if [ ${#NAMES[@]} -lt 1 ]
then
    echo "ERROR: Required argument missing"
    print_usage
    exit 1
fi

# Will get set by one of the paths below
REAL_SNAPSHOT=
REAL_DATASET=
SNAPSHOT_NAME=
DATASET=


# Is the provided dataset a snapshot?
if echo "${SOURCE_DATASET}" | grep -q "@" ; then
    # get just the name of the snapshot
    SNAPSHOT_NAME=$(echo "${SNAPSHOT}" | sed -e 's/^.*@//g')
    # Get the dataset for the snapshot
    DATASET=$(echo "${SNAPSHOT}" | sed -e 's/@.*$//g')
else
    SNAPSHOT_NAME=
    DATASET=${SOURCE_DATASET}
fi

# Get all datasets from BASE_ZPOOL and BASE_CLONE_ZPOOL that end with a match of the specified dataset
FULL_DATASET=()
mapfile -t FULL_DATASET < <(sudo zfs list -r ${TOP_ZPOOL} | awk '{if(NR>1)print $1}' | grep -E "^(${BASE_ZPOOL}|${BASE_CLONE_ZPOOL})" | grep "${DATASET}$" 2>/dev/null)
if [ ${#FULL_DATASET[@]} -eq 0 ] ; then
    echo "ERROR: No matching dataset found: ${DATASET}"
    exit 1
elif [ ${#FULL_DATASET[@]} -gt 1 ] ; then
    echo "ERROR: Ambiguous dataset specified: ${DATASET}"
    exit 1
fi
# only 1 found, it's the one we want
REAL_DATASET=${FULL_DATASET[0]}

# already have the snapshot specified?
if [ -n "${SNAPSHOT_NAME}" ] ; then
    REAL_SNAPSHOT=${REAL_DATASET}@${SNAPSHOT_NAME}
    # confirm it really exists
    if ! sudo zfs list -r ${REAL_DATASET} -t snapshot | grep -q "^${REAL_SNAPSHOT}$" 2>/dev/null; then
        echo "ERROR: Snapshot specified doesn't exist: ${REAL_SNAPSHOT}"
        exit 1
    fi
else
    # Make sure we have the BASE_CLONE_ZPOOL
    if ! sudo zfs list -r ${TOP_ZPOOL} | awk '{if(NR>1)print $1}' | grep -q "${BASE_CLONE_ZPOOL}$" 2>/dev/null ; then
        #BASE_ZPOOL doesn't exist, try to create it
        if ! sudo zfs create -o canmount=noauto -o overlay=on -o sharesmb=off -o exec=on ${BASE_CLONE_ZPOOL} &>/dev/null; then
            echo "ERROR: Unable to create ${BASE_CLONE_ZPOOL}, possible due to missing intermediate datasets"
            exit 1
        fi
    fi

    # Name the new snapshot based on date-time and create it
    REAL_SNAPSHOT=${REAL_DATASET}@$(date +"%Y%m%d%H%m%S")

    echo -e "${CMagentaForeground}${CBold}""Creating new snapshot: ${REAL_SNAPSHOT}""${CNone}"

    if ! sudo zfs snapshot -r ${REAL_SNAPSHOT} &>/dev/null; then
        echo "ERROR: Couldn't create snapshot: ${REAL_SNAPSHOT}"
        exit 1
    fi

fi

# We can now assume we have a snapshot to clone as many times as needed


CLONE_TO_CLEANUP_ON_FAILURE=
CLONE_DIR_TO_CLEANUP_ON_FAILURE=
cleanup_failed_zfs_clone()
{
    # clean up the previous clone that just failed
    if [ -n "${CLONE_TO_CLEANUP_ON_FAILURE}" ] && sudo zfs list -r ${BASE_CLONE_ZPOOL} | awk '{if(NR>1)print $1}' | grep -q "^${CLONE_TO_CLEANUP_ON_FAILURE}$" ; then
        sudo zfs umount ${BASE_DATASET_FULLNAME} &>/dev/null
        sudo zfs destroy ${CLONE_TO_CLEANUP_ON_FAILURE} 
    fi
    if [ -n "${CLONE_DIR_TO_CLEANUP_ON_FAILURE}" ] && [ -d ${CLONE_DIR_TO_CLEANUP_ON_FAILURE} ]
    then
        rm -rf ${CLONE_DIR_TO_CLEANUP_ON_FAILURE}
    fi
}

# should never fail this check, but just to be sure...
if [ -z "${REAL_SNAPSHOT}" ] ; then
    echo "ERROR: No snapshot to work from"
fi

trap "cleanup_failed_zfs_clone" EXIT
for N in ${NAMES[@]}
do
    echo -e "${CMagentaForeground}${CBold}Creating new clone in ${MSDK_BASEDIR}/${N}${CNone}"

    # Set this so any failure will clean up after it
    CLONE_DIR_TO_CLEANUP_ON_FAILURE=${MSDK_BASEDIR}/${N}
    CLONE_TO_CLEANUP_ON_FAILURE=${BASE_CLONE_ZPOOL}/${N}

    if ! sudo zfs clone -o mountpoint=${CLONE_DIR_TO_CLEANUP_ON_FAILURE} -o canmount=on -o readonly=off ${REAL_SNAPSHOT} ${CLONE_TO_CLEANUP_ON_FAILURE} &>/dev/null ; then
        echo "ERROR: Could not create ${N}"
        exit 1
    else
        # we successfully cloned it, we don't need to do any further cleanup on it
        CLONE_DIR_TO_CLEANUP_ON_FAILURE=
        CLONE_TO_CLEANUP_ON_FAILURE=
    fi
done
trap "" EXIT


