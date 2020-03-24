#!/bin/bash

MSDK_BASEDIR=${HOME}/msdk_code_repos

CMagentaForeground="\\033[35m"
CBold="\\033[1m"
CNone="\\033[0m"

print_usage()
{
    echo "USAGE"
    echo "  $0 name-of-clone [name-of-clone2 ...]"
    echo ""
    echo " Removes and cleans up a clone, cleaning up any orphaned containers."
    echo ""
    echo "ARGUMENTS"
    echo ""
    echo "  name-of-clone"
    echo "   Name of the clone to clean up.  Can be repeated to be run for multiple clones."
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
    echo -e "${CMagentaForeground}${CBold}""Removing clone in ${MSDK_BASEDIR}/${N}""${CNone}"

    if [ -d "${MSDK_BASEDIR}/$N" ] ; then
        containers_rmmsdk.sh ${N}
        sudo rm -rf ${MSDK_BASEDIR}/${N}
    else
        echo "ERROR: ${MSDK_BASEDIR}/${N} doesn't exist"
    fi
done


