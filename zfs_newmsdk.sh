#!/bin/bash

MSDK_BASEDIR=${HOME}/msdk_code_repos
REPO_URL=git@scm-02.karlstorz.com:VPD-SW/Dev/modularSDK.git
TOP_ZPOOL=${TOP_ZPOOL:-phyhomedir/home} # this must already exist
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
    echo "  $0 [-b branch-name1 |--branch=branch-name1] [-i branch-name2 | --inherit branch-name2] [-f dataset-name | --from dataset-name] name-of-clone [name-of-clone2 ...]"
    echo ""
    echo " Uses git-fast-clone to create a clone of the modularSDK using the normal git clone syntax and automatically runs"
    echo " git externals on it. Allows specifying the branch name to check out on the modularSDK, and an additional"
    echo " optional branch name to use when running git externals."
    echo " Clones are created in ${MSDK_BASEDIR} as separate ZFS subvolumes so they can be copied and duplicated easily."
    echo " Clones occur using SSH syntax, so SSH key must be properly configured."
    echo ""
    echo "ARGUMENTS"
    echo "  -b branch-name1"
    echo "  --branch=branch-name1"
    echo "   The name of the branch to checkout on the repo-url.  Fails if the branch listed doesn't exist."
    echo "   Optional argument, will use the default branch the repo specifies if not included."
    echo "   Note that if the -i or --inherit option is used and this option is not, it will try to check out"
    echo "   the branch listed for that option, but will not fail if it doesn't exist."
    echo "   If this is specified when -i or --inherit are not, this will also be used as the inherit option"
    echo "   when checking out the sub-repos with git-externals."
    echo "   Repeats of this option overwrite previous instances working left to right."
    echo ""
    echo "  -f dataset-name"
    echo "  --from dataset-name"
    echo "   The name of the zfs dataset to create it from.  Creates a new dataset and snapshot otherwise."
    echo "   Optional argument, will create a new dataset, fill it, and snapshot it for the new zfs clone"
    echo "   if this argument isn't used.  If this is set, it can either specify a snapshot, or a dataset that"
    echo "   needs a snapshot made.  It will create a new zfs clone from the existing or created snapshot"
    echo "   listed, which is assumed to be from a previously created base dataset.  dataset-name can be the "
    echo "   full pool and volume name followed by the snapshot name, just the final dataset name, or anything"
    echo "   between. e.g. for tank/home/msdk/int_trunk_20190306123030@base either the full name or"
    echo "   just \"int_trunk_20190306123030@base\" to use the \"base\" snapshot, or "
    echo "   \"int_trunk_20190306123030\" if a new snapshot should be created from it and used."
    echo ""
    echo "  -i branch-name2"
    echo "  --inherit branch-name2"
    echo "   The name of the branch to try checking out for all sub-repos when running git-externals."
    echo "   If a sub-repo doesn't have this branch name available, it will not produce any error."
    echo "   If this is specified but -b or --branch is not, then this branch name will also be used"
    echo "   when checking out the top level repo, but unlike --branch it won't fail if a matching branch"
    echo "   wasn't found."
    echo "   If -b or --branch is specified when this is not, the default for this option is the branch"
    echo "   name specified to -b or --branch."
    echo "   Repeats of this option overwrite previous instances working left to right."
    echo "   WARNING: The inherit logic relies on properly configured .gitexternals files in all the repos"
    echo "            that list \${INHERIT} as the first branch option."
    echo ""
    echo "  name-of-clone"
    echo "   Name to create the clone under.  Standard syntax for git-fast-clone on this argument applies."
    echo "   Note that this can be a path to a folder as long as all intermediate paths already exist."
    echo "   Can be repeated for additional names of clones to also create.  When repeated for additional"
    echo "   repo clones, all will be zfs clones from the same snapshot."
    echo ""
}

OPTS=$(getopt -n "$(basename $0)" --options hb:i:f: --longoptions help,branch:,inherit:,from: -- "$@")
if [ $? -ne 0 ]
then
    echo "ERROR: Unable to parse arguments"
    print_usage
    exit 1
fi

eval set -- "$OPTS"

PASSTHRU_ARGS=()
NAMES=()
FREE_ARGS=false
BASE_DATASET_NAME=int_trunk
SNAPSHOT=

# we don't allow empty double quote arguments so don't worry about that corner case here
while [ -n "$1" ]
do
    case $1 in
        -h | --help )
            print_usage
            exit 0
            ;;
        -b | -i )
            PASSTHRU_ARGS+=("$1 $2")
            BASE_DATASET_NAME="$2"
            shift 2
            ;;
        --branch | --inherit )
            PASSTHRU_ARGS+=("$1=$2")
            BASE_DATASET_NAME="$2"
            shift 2
            ;;
        -f | --from )
            SNAPSHOT="$2"
            shift 2
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

# No snapshot explicitly specified?
if [ -z "${SNAPSHOT}" ] ; then # need to create the base dataset
    # clean up the base dataset name (tries to use a cleaned up branch name)
    BASE_DATASET_NAME=$(echo "${BASE_DATASET_NAME}" | sed -E -e 's@[^a-zA-Z0-9_-]@_@g')
    # add a unique time code
    BASE_DATASET_NAME=${BASE_DATASET_NAME}-$(date +"%Y%m%d%H%m%S")

    # Make sure we have the BASE_ZPOOL
    if ! sudo zfs list -r ${TOP_ZPOOL} | awk '{if(NR>1)print $1}' | grep -q "${BASE_ZPOOL}$" ; then
        #BASE_ZPOOL doesn't exist, try to create it
        if ! sudo zfs create -o canmount=noauto -o overlay=on -o sharesmb=off -o exec=on ${BASE_ZPOOL} ; then
            echo "ERROR: Unable to create ${BASE_ZPOOL}, possible due to missing intermediate datasets"
            exit 1
        fi
    fi

    # prepend the subvolume name
    BASE_DATASET_FULLNAME=${BASE_ZPOOL}/${BASE_DATASET_NAME}
    echo -e "${CMagentaForeground}${CBold}""Creating new base datset: ${BASE_DATASET_FULLNAME}""${CNone}"

    TMP_CLONE_PATH=${MSDK_BASEDIR}/${BASE_DATASET_NAME}

    cleanup_failed_zfs_base_create()
    {
        # clean up the previous ZFS base 
        if [ -n "${BASE_DATASET_FULLNAME}" ] && sudo zfs list -r ${BASE_ZPOOL} | awk '{if(NR>1)print $1}' | grep -q "^${BASE_DATASET_FULLNAME}$" ; then
            sudo zfs umount ${BASE_DATASET_FULLNAME}
            sudo zfs destroy ${BASE_DATASET_FULLNAME}
        fi
        if [ -n "${TMP_CLONE_PATH}" ] && [ -d ${TMP_CLONE_PATH} ]
        then
            rm -rf ${TMP_CLONE_PATH}
        fi
    }

    trap "cleanup_failed_zfs_base_create" EXIT

    # create a temporary mount-point
    mkdir -p ${TMP_CLONE_PATH}
    sudo chown ${USER}:${USER} ${TMP_CLONE_PATH}

    # create it and mount it to the temporary location
    if ! sudo zfs create -o mountpoint=${TMP_CLONE_PATH} -o canmount=on ${BASE_DATASET_FULLNAME} ; then
        echo "ERROR: Couldn't create the base zfs dataset"
        exit 1
    fi

    # we have to change the ownership of this AFTER mounting the new ZFS dataset, because the mounting
    # modifies the ownership from what it was before
    sudo chown ${USER}:${USER} ${TMP_CLONE_PATH}

    # Clone the new sandbox into the zfs dataset
    if ! newclone ${PASSTHRU_ARGS[@]} ${REPO_URL} ${TMP_CLONE_PATH}
    then
        echo "ERROR: Could not clone sandbox"
        exit 1
    fi

    trap "" EXIT

    # unmount it
    if ! sudo zfs unmount ${BASE_DATASET_FULLNAME} ; then
        echo "ERROR: Unable to unmount the dataset ${BASE_DATASET_FULLNAME}"
        exit 1
    fi

    # set it not to automatically mount anymore
    sudo zfs set canmount=noauto ${BASE_DATASET_FULLNAME}

    # remove the old mount point
    if ! rmdir ${TMP_CLONE_PATH} ; then
        echo "ERROR: Couldn't remove the temporary mountpoint ${TMP_CLONE_PATH}"
        exit 1
    fi

    # let it create the snapshot from our base
    SNAPSHOT=${BASE_DATASET_FULLNAME}
fi

# now call to create a snapshot (possibly) and the cloned copy
zfs_mk_clone.sh ${SNAPSHOT} ${NAMES[@]}
