#!/bin/bash
set -e

export OS_URL=http://127.0.0.1:6385
export OS_TOKEN=fake

DIR_REPORT="$PWD/reports"
mkdir -p $DIR_REPORT
FILE_REPORT="$DIR_REPORT/report-$(date +%Y%m%d-%H%M%S.%N)"
touch $FILE_REPORT
FILE_TEMP="$DIR_REPORT/temp"
TOTAL_SEC=0
TOTAL_SUCCESS=0
TOTAL_FAILED=0

BAREMETAL_NAME="ibmc-stress-test"
BAREMETAL_DEPLOY_KERNEL="file:///var/lib/ironic/http/deploy/coreos_production_pxe.vmlinuz"
BAREMETAL_DEPLOY_RAMDISK="file:///var/lib/ironic/http/deploy/coreos_production_pxe_image-oem.cpio.gz"
BAREMETAL_IBMC_ADDR="https://112.93.129.9"
BAREMETAL_IBMC_USER="****"
BAREMETAL_IBMC_PASS="****"
BAREMETAL_MACS=('58:F9:87:7A:A9:73' '58:F9:87:7A:A9:74' '58:F9:87:7A:A9:75' '58:F9:87:7A:A9:76')
BAREMETAL_IMAGE="http://112.93.129.99/images/ubuntu-xenial-16.04.qcow2"
BAREMETAL_IMAGE_CHECKSUM="f3e563d5d77ed924a1130e01b87bf3ec"

function usage {
  cat <<EOF
    USAGE
        `basename $0` [-d] [-i number_of_iteration] [-a ibmc_address] 
                 [-u ibmc_user] [-p ibmc_password]

    DESCRIPTION
        Stress test script for ibmc.

        -i number_of_iteration
            Number of iteration, if not specified, will prompt for input
        
        -a ibmc_address
            IBMC address, e.g. http://ip[:port], if not specified, will prompt for input
        
        -u ibmc_user
            IBMC username, if not specified, will prompt for input

        -p ibmc_password
            IBMC password, if not specified, will prompt for input

        -d
            Delete node with name [$BAREMETAL_NAME] without prompt
        
        -h
            Show this help message
EOF
    exit 1
}

function build_node {
    local NODE=$(openstack baremetal node create --name "$BAREMETAL_NAME" \
    --driver "ibmc" --driver-info ibmc_address="$BAREMETAL_IBMC_ADDR" \
    --driver-info ibmc_username="$BAREMETAL_IBMC_USER" \
    --driver-info ibmc_password="$BAREMETAL_IBMC_PASS" \
    --driver-info ibmc_verify_ca="False" \
    --driver-info deploy_kernel="$BAREMETAL_DEPLOY_KERNEL" \
    --driver-info deploy_ramdisk="$BAREMETAL_DEPLOY_RAMDISK" \
    -f value -c uuid)

    for mac in "${BAREMETAL_MACS[@]}"
    do
        openstack baremetal port create --node $NODE "$mac" > /dev/null 2>&1
    done

    openstack baremetal node set "$NODE" \
    --instance-info image_source="$BAREMETAL_IMAGE" \
    --instance-info image_checksum="$BAREMETAL_IMAGE_CHECKSUM" \
    --instance-info root_gb="10"

    # In case node has been lock, manage node after 2 seconds
    sleep 2
    openstack baremetal node manage $NODE
    openstack baremetal node provide $NODE

    local START=$(date +%s)
    openstack baremetal node deploy $NODE

    local IFS=$'\t'
    local TARGET_PROVISION_STATE=('active\tdeploy failed')
    unset IFS
    local PROVISION_STATE='wait call-back'
    until [[ "${TARGET_PROVISION_STATE[@]}" =~ "$PROVISION_STATE" ]]
    do
        sleep 1
        PROVISION_STATE=$(openstack baremetal node show $NODE -f value -c provision_state)
    done
    local END=$(date +%s)

    if [[ "$PROVISION_STATE" == "active" ]]
    then
        (( TOTAL_SUCCESS += 1 ))
    else
        (( TOTAL_FAILED += 1 ))
    fi
    local DIFF=$(( END-START ))
    local DIFF_IN_MIN=$(( DIFF/60 ))
    local DIFF_REMAINDER=$(( DIFF%60 ))
    (( TOTAL_SEC += DIFF ))
    echo "${DIFF_IN_MIN} min ${DIFF_REMAINDER} sec, $PROVISION_STATE" >> $FILE_REPORT
}

function delete_node {
    local NODE="$1"
    openstack baremetal node maintenance set $NODE
    openstack baremetal node delete $NODE > /dev/null 2>&1
}

function check_node_exist {
    local UUID=$(openstack baremetal node show $BAREMETAL_NAME -f value -c uuid 2> /dev/null)
    
    if [[ -z "$UUID" ]]
    then
        # Not exist, do nothing
        return
    else
        if [[ "$DELETE_EXIST_NODE" -eq "1" ]]
        then
            delete_node $BAREMETAL_NAME
            return
        else
            local MSG="A node with name [$BAREMETAL_NAME] exist, delete it or exit the program: "
            echo $MSG
            local CHOICE=('Delete it' 'Exit the program')
            select YN in "${CHOICE[@]}"
            do
                case $YN in
                    ${CHOICE[0]})
                        delete_node $BAREMETAL_NAME; break;
                        ;;
                    ${CHOICE[1]})
                        exit
                        ;;
                    *)
                        echo "Please select OP in ($(eval echo {1..${#CHOICE[@]}}))"
                        ;;
                esac
            done
        fi
    fi
}


# Parse argments
NO_ARGS=0 
E_OPTERROR=85
# Default number of iteration
DEFAULT_NUM_ITER=2
# Whether to delete exist node with name $BAREMETAL_NAME
# 0: prompt if there exist node with name $BAREMETAL_NAME
# 1: delete without prompt
DELETE_EXIST_NODE=0

if [ $# -eq "$NO_ARGS" ]
then

    read -p "Enter number of iteration(default $DEFAULT_NUM_ITER): " NUM_ITER
    read -p "Enter ibmc address(default $BAREMETAL_IBMC_ADDR): " IBMC_ADDR
    read -p "Enter ibmc user(default $BAREMETAL_IBMC_USER): " IBMC_USER
    read -p "Enter ibmc password(default $BAREMETAL_IBMC_PASS): " IBMC_PASS
else
while getopts ":i:a:u:p:dh" OP
do
    case $OP in
        i) 
            NUM_ITER=$OPTARG
            ;;
        a)
            BAREMETAL_IBMC_ADDR="$OPTARG"
            ;;
        u)
            BAREMETAL_IBMC_USER="$OPTARG"
            ;;
        p)
            BAREMETAL_IBMC_PASS="$OPTARG"
            ;;
        d)
            DELETE_EXIST_NODE=1
            ;;
        *) 
            usage
            ;;
    esac
done
fi  

shift $(($OPTIND - 1))

# Number of iteration
NUM_ITER=${NUM_ITER:-$DEFAULT_NUM_ITER}
BAREMETAL_IBMC_ADDR=${IBMC_ADDR:-$BAREMETAL_IBMC_ADDR}
BAREMETAL_IBMC_USER=${IBMC_USER:-$BAREMETAL_IBMC_USER}
BAREMETAL_IBMC_PASS=${IBMC_PASS:-$BAREMETAL_IBMC_PASS}

# Check node with name $BAREMETAL_NAME exist
check_node_exist

echo "Number of iteration: $NUM_ITER"
echo "IBMC address: $BAREMETAL_IBMC_ADDR"
echo "IBMC username: $BAREMETAL_IBMC_USER"
echo "IBMC password: $BAREMETAL_IBMC_PASS"
echo "Report file: $FILE_REPORT"
echo "Please wait until this program complete..."

for ((i=1; i<=NUM_ITER; i++))
do
    echo "Node $i building..."
    build_node
    echo "Node $i built"
    echo "Node $i deleting..."
    delete_node $BAREMETAL_NAME
    echo "Node $i deleted"
done

echo "Report file: $FILE_REPORT"

TOTAL_SEC_IN_MIN=$(( TOTAL_SEC/60 ))
TOTAL_SEC_REMAINDER=$(( TOTAL_SEC%60 ))
AVG_SEC=$(( TOTAL_SEC/NUM_ITER ))
AVG_SEC_IN_MIN=$(( AVG_SEC/60 ))
AVG_SEC_REMAINDER=$(( AVG_SEC%60 ))
REPORT="\n
\tTotal node built:\t\t$NUM_ITER\n
\tTotal time cost:\t\t$TOTAL_SEC_IN_MIN min $TOTAL_SEC_REMAINDER sec\n
\tAverage time cost:\t\t$AVG_SEC_IN_MIN min $AVG_SEC_REMAINDER sec\n
\tTotal node active:\t\t$TOTAL_SUCCESS\n
\tTotal node failed:\t\t$TOTAL_FAILED\n"
echo -e $REPORT | cat - $FILE_REPORT > $FILE_TEMP && mv $FILE_TEMP $FILE_REPORT

echo -e $REPORT