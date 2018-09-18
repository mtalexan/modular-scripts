#!/bin/bash

print_usage()
{
    echo "USAGE"
    echo "  $0 [-b branch-name1 |--branch=branch-name1] [-i branch-name2 | --inherit branch-name2] repo-url [name-of-clone]"
    echo ""
    echo " Uses git-fast-clone to create a clone of the repo-url using the normal git clone syntax and automatically runs"
    echo " git externals on it. Allows specifying the branch name to check out on the listed repo, and an additional"
    echo " optional branch name to use when running git externals."
    echo " Clones are created in the directory this script is run from."
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
    echo "  repo-url"
    echo "   Required URL to perform the clone from.  Standard git-fast-clone syntax applies."
    echo ""
    echo "  name-of-clone"
    echo "   Optional name to create the clone under.  Standard syntax for git-fast-clone on this argument applies."
    echo "   Note that this can be a path to a folder as long as all intermediate paths already exist."
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

BRANCH=
INHERIT=
REPO_URL=
NAME=
FREE_ARGS=false

# we don't allow empty double quote arguments so don't worry about that corner case here
while [ -n "$1" ]
do
    case $1 in
        -h | --help )
            print_usage
            exit 0
            ;;
        -b | --branch )
            BRANCH=$2
            shift 2
            ;;
        -i | --inherit )
            INHERIT=$2
            shift 2
            ;;
        -- )
            FREE_ARGS=true
            shift
            ;;
        * )
            if ${FREE_ARGS}
            then
                if [ -n "${NAME}" ]
                then
                    echo "ERROR: Too many arguments"
                    print_usage
                    exit 1
                elif [ -n "${REPO_URL}" ]
                then
                    NAME=$1
                    shift
                else
                    REPO_URL=$1
                    shift
                fi
            else
                echo "ERROR: Unrecognized argument \"$1\""
                print_usage
                exit 1
            fi
            ;;
    esac
done

# if inherit isn't set, it defaults to branch (if that is set)
if [ -z "${INHERIT}" ] && [ -n "${BRANCH}" ]
then
    INHERIT=${BRANCH}
fi

# Default name git gives directories is the repo name without the .git ending
# and we need to know what directory to change into.
if [ -z "${NAME}" ]
then
    NAME=$(echo "${REPO_URL}" | sed -E -e 's@^.*/([^/]+)$@\1@' -e 's@.git$@@')
fi

if ! git fast-clone ${REPO_URL} ${NAME}
then
    echo "ERROR: Unable to fast-clone ${REPO_URL} to ${NAME}"
    exit 1
fi

cd ${NAME}

# check out the top level branch if specified, or try falling back to optional INHERIT value.
# If neither, leave it at the default branch
if [ -n "${BRANCH}" ]
then
    if ! git checkout ${BRANCH}
    then
        echo "ERORR: No matching branch found: ${BRANCH}"
        exit 1
    fi
elif [ -n "${INHERIT}" ]
then
    echo "Looking for branch origin/${INHERIT}"
    if git rev-parse --verify --quiet origin/${INHERIT} &>/dev/null
    then
        if ! git checkout --track origin/${INHERIT}
        then
            echo "ERORR: Matching branch found, but unable to check it out: --track origin/${INHERIT}"
            exit 1
        fi
    else
        echo "Not found."
    fi
fi

# git-externals uses this variable for the variable all sub-repos should try to checkout first (if listed in the .gitexternals file)
export INHERIT

# Run git-externals with the INHERIT branch prefered for all sub-repos
if ! INHERIT=${INHERIT} git externals
then
    echo "ERROR: git-externals failed"
    exit 1
else
    echo "Success"
    exit 0
fi
