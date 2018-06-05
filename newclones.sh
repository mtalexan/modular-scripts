#!/usr/bin/env bash

usage()
{
    cat <<EOF
    USAGE: $0 [<options>] <name> [<repo-url>]

    Creates the sandbox clones of modularSDK for each mach type in the correct directory using
    a basename and appending each of the mach types.

    Options:
      -h|--help
        Print this help text.
      -b|--branch
        The branch name to use in the modularSDK repository.  Sets INHERIT so
        the same branch name will be attempted for all the git externals. If the branch
        doesn't exist on modularSDK, this generates a warning only, since the option may be
        intended for the INHERIT portion of its use.  Defaults to the repository default if not specified.
      -m|--mod|--modular
        The branch name to use in the modular repository.  Overrides
        the branch name specified in the gitexternals file, but only after
        git externals has already been run.  Generates an error if the branch doesn't exist.
      -s|--sdk
        The branch name to use in the sdk.  Defaults to what's specified
        in the modularSDK .gitexternals file.  Generates an error if the branch doesn't exist.
    Arguments:
      <name>
        The base name to give the repos.  The different mach types are added to the end of this name.
      <repo-url>
        The URL to clone from.  Defaults to git@gol-gitlab.kstg.corp:VPD-SW/Dev/modularSDK.git
EOF
}

OPTIONS=$(getopt -n $0 -o hb:m:s: --long help,branch:,mod:,modular:,sdk: -- "$@")
[[ $? -ne 0 ]] && usage

eval set -- "${OPTIONS}"

export MSDK_BRANCH=
export MOD_BRANCH=
export SDK_BRANCH=
export BASE_NAME=
export REPO_URL=git@gol-gitlab.kstg.corp:VPD-SW/Dev/modularSDK.git
EXTRA_ARGS=false
EARG_CNT=0

while [ $# -ge 1 ] ; do
    case $1 in
        -h|--help)
            usage
            shift
            exit 0
            ;;
        -b|--branch)
            MSDK_BRANCH=$2
            shift 2
            ;;
        -m|--mod|--modular)
            MOD_BRANCH=$2
            shift 2
            ;;
        -s|--sdk)
            SDK_BRANCH=$2
            shift 2
            ;;
        --)
            EXTRA_ARGS=true
            shift
            ;;
        *)
            if ${EXTRA_ARGS} ; then
                if [ $EARG_CNT -eq 0 ] ; then
                    BASE_NAME=$1
                elif [ $EARG_CNT -eq 1 ] ; then
                    REPO_URL=$1
                fi
                shift
            else
                usage
                shift
                exit 1
            fi
            ;;
    esac
done

if [ -z "${BASE_NAME}" ] ; then
    echo "ERROR: Missing a base name"
    usage
    exit 1
fi

MACH_TYPES=(garibaldi phish generic)

export MSDK_BASEDIR=${HOME}/msdk_code_repos

# 1: The mach type
# Any globals this needs must be exported since this runs in a subshell
function make_clone() {
    CLONEDIR=${MSDK_BASEDIR}/${BASE_NAME}-${1}

    git fast-clone ${REPO_URL} ${CLONEDIR}
    if [ $? -ne 0 ] ; then
        echo "ERROR: unable to clone modularSDK from ${REPO_URL} to ${CLONEDIR}"
        exit 1
    fi

    pushd ${CLONEDIR} &>/dev/null

    if [ -n "${MSDK_BRANCH}" ] ; then
        git checkout ${MSDK_BRANCH}
        if [ $? -ne 0 ] ; then
            # Warning only
            echo "Warning: no modularSDK branch name: ${MSDK_BRANCH}"
        fi
        INHERIT=${MSDK_BRANCH} git externals
    else
        git externals
    fi

    if [ -n "${SDK_BRANCH}" ] ; then
        pushd sdk/origin &>/dev/null

        git checkout ${SDK_BRANCH}
        if [ $? -ne 0 ] ; then
            echo "ERROR: bad sdk branch name: ${SDK_BRANCH}"
        fi

        popd &>/dev/null
    fi

    if [ -n "${MOD_BRANCH}" ] ; then
        pushd modular &>/dev/null

        git checkout ${MOD_BRANCH}
        if [ $? -ne 0 ] ; then
            echo "ERROR: bad modular branch name: ${MOD_BRANCH}"
        fi

        popd &>/dev/null
    fi

    popd &>/dev/null
}
# it's going to be run in a subshell
export -f make_clone

# run the creation of each of these in parallel
parallel -i bash -c "make_clone {}" -- ${MACH_TYPES[@]}
if [ $? -eq 0 ] ; then
    # produce the list of final sandbox names
    NAMED_TYPES=()
    for T in ${MACH_TYPES[@]} ; do
        NAMED_TYPES+=("${BASE_NAME}-${T}")
    done

    echo "Successfully created: ${NAMED_TYPES[@]}"
fi

