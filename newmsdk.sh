#!/bin/bash

MSDK_BASEDIR=${HOME}/msdk_code_repos
REPO_URL=git@scm-02.karlstorz.com:VPD-SW/Dev/modularSDK.git

CMagentaForeground="\\033[35m"
CBold="\\033[1m"
CNone="\\033[0m"

print_usage()
{
    echo "USAGE"
    echo "  $0 [-b branch-name1 |--branch=branch-name1] [-i branch-name2 | --inherit branch-name2] name-of-clone [name-of-clone2 ...]"
    echo ""
    echo " Uses git-fast-clone to create a clone of the modularSDK using the normal git clone syntax and automatically runs"
    echo " git externals on it. Allows specifying the branch name to check out on the modularSDK, and an additional"
    echo " optional branch name to use when running git externals."
    echo " Clones are created in ${MSDK_BASEDIR}"
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
    echo "   Can be repeated for additional names of clones to also create."
    echo ""
}

OPTS=$(getopt -n "$(basename $0)" --options hb:i: --longoptions help,branch:,inherit: -- "$@")
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
            shift 2
            ;;
        --branch | --inherit )
            PASSTHRU_ARGS+=("$1=$2")
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

# try to create it if we don't have one yet
mkdir -p ${MSDK_BASEDIR}

if ! cd ${MSDK_BASEDIR}
then
    echo "ERROR: Root directory for all clones not found: ${MSDK_BASEDIR}"
    exit 1
fi

CLONE_TO_CLEANUP_ON_FAILURE=
cleanup_failed_parent_clone()
{
    if [ -n "${CLONE_TO_CLEANUP_ON_FAILURE}" ] && [ -d ${CLONE_TO_CLEANUP_ON_FAILURE} ]
    then
        echo "Cleaning up failed clone: ${CLONE_TO_CLEANUP_ON_FAILURE}  ..."
        rm -rf ${CLONE_TO_CLEANUP_ON_FAILURE}
    fi
}

trap EXIT "cleanup_failed_parent_clone"

for N in ${NAMES[@]}
do
    echo -e "${CMagentaForeground}${CBold}Creating new clone in ${MSDK_BASEDIR}/${N}${CNone}"

    # Set this so any failure will clean up after it
    CLONE_TO_CLEANUP_ON_FAILURE=${MSDK_BASEDIR}/${N}

    if ! newclone ${PASSTHRU_ARGS[@]} ${REPO_URL} ${N}
    then
        echo "ERROR: Could not create ${N}"
        exit 1
    else
        # we successfully cloned it, we don't need to do any further cleanup on it
        CLONE_TO_CLEANUP_ON_FAILURE=
    fi
done


