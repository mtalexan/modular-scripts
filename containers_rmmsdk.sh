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
    echo " Removes any containers associated with a named clone(s)."
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

# Finds the name of the container for a clone
#  1: The root path of the clone to get the container names from
# Return:
#  Sets ${CONTAINERS[@]} to hold the container names used by the clone
find_container_names()
{
    CONTAINERS=()

    if [ -z "$1" ] ; then
        # missing argument
        return 1
    fi

    local NAME_FILES=()
    # get all possible files with that name
    mapfile -t NAME_FILES < <(find "$1"/sdk -maxdepth 3 -name ".container" &>/dev/null)


    if [ ${#NAME_FILES[@]} -gt 0 ] ; then
        for N in ${NAME_FILES[@]} ; do
            CONTAINERS+=($(cat ${N}))
        done
    fi

    return 0
}

# Removes a container
# 1-?: Names of containers to delete
remove_containers()
{
    if [ -z "$@" ] ; then
        return 1
    fi

    local ret=0
    local tret=0

    for N in $@ ; do
        # does the container name exist in the list of containers present on the system?
        if ! lxc list --format=csv -cn | grep -q "^${N}$" ; then
            echo "No cleanup necessary for container: $N"
        else
            echo "Cleaning up container: $N"
            # force stop as well if necessary
            lxc delete --force $N >/dev/null
            tret=$?
            if [ $tret -ne 0 ] ; then
                echo "ERROR: couldn't clean up container $N"
                if [ $ret -eq 0 ] ; then
                    ret=$tret
                fi
            fi
        fi
    done
    return $ret
}

CONTAINERS=()

for N in ${NAMES[@]}
do
    echo -e "${CMagentaForeground}${CBold}""Removing containers for clone in ${MSDK_BASEDIR}/${N}""${CNone}"

    if [ -d $N ] ; then
        find_container_names ${MSDK_BASEDIR}/${N}
        if [ ${#CONTAINERS[@]} -gt 0 ] ; then
            remove_containers ${CONTAINERS[@]}
        else
            echo "No containers to clean up"
        fi
    else
        echo "ERROR: ${MSDK_BASEDIR}/${N} doesn't exist"
    fi
done


