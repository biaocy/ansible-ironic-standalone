#!/bin/bash

IRONIC_INSTALLED="`pip show ironic --disable-pip-version-check | grep '^Name'`"

# Python dist-packages dir
PY_DIST_DIR="`pip show ironic --disable-pip-version-check | grep '^Location' | cut -d' ' -f2`"
IRONIC_VERSION="`pip show ironic --disable-pip-version-check | grep '^Version' | cut -d' ' -f2`"

# Check required parameters
: ${IRONIC_INSTALLED:?"Ironic not install! Do not patch!"}
: ${PY_DIST_DIR:?"Python dist-packages dir not found! Patch failed!"}
: ${IRONIC_VERSION:?"Can not determine Iroinc version! Patch failed!"}

# Ironic install dir
IRONIC_DIR="$PY_DIST_DIR/ironic"
# Ironic egg info dir
IRONIC_EGG_DIR="$PY_DIST_DIR/ironic-$IRONIC_VERSION.egg-info"
# Ironic config file
IRONIC_CONF_FILE="/etc/ironic/ironic.conf"

# Files and copys path
BAK_SUFFIX='.bak'
PATH_CONF_INIT="$IRONIC_DIR/conf/__init__.py"
PATH_CONF_INIT_BAK="$IRONIC_DIR/conf/__init__.py$BAK_SUFFIX"
PATH_COMMON_EXCEPTION="$IRONIC_DIR/common/exception.py"
PATH_COMMON_EXCEPTION_BAK="$IRONIC_DIR/common/exception.py$BAK_SUFFIX"
PATH_ENTRY_POINTS="$IRONIC_EGG_DIR/entry_points.txt"
PATH_ENTRY_POINTS_BAK="$IRONIC_EGG_DIR/entry_points.txt$BAK_SUFFIX"

# Ironic release
IRONIC_REL_QUEENS="queens"
IRONIC_REL_ROCKY="rocky"

# Patch function 
function patch {
    # Ironic release
    IRONIC_RELEASE = "$1"
    # Check Ironic release, if absent, do nothing and return
    if [ -z "$IRONIC_RELEASE" ]
    then
        echo "Do nothing. Need ironic release to patch."
        return 1
    fi
    # Patch file
    PATCH_FILE="$PWD/patch_for_$IRONIC_RELEASE.tar"

    if [ ! -e "$PATCH_FILE" ]
    then
        echo "Do nothing. Patch file[$PATCH_FILE] do not exist!"
        return 2
    fi

    # Extract added patch files to Python dist-packages
    tar -xf $PATCH_FILE -C $PY_DIST_DIR

    # Make copy, in case something broken after this script run,
    #  we can restore these file to recover ironic service
    cp $PATH_CONF_INIT $PATH_CONF_INIT_BAK
    cp $PATH_COMMON_EXCEPTION $PATH_COMMON_EXCEPTION_BAK

    # Add iBMC driver option register code
    # echo >> $PATH_CONF_INIT
    # echo 'from ironic.conf import ibmc' >> $PATH_CONF_INIT
    # echo 'ibmc.register_opts(CONF)' >> $PATH_CONF_INIT
    echo "
from ironic.conf import ibmc
ibmc.register_opts(CONF)
" >> $PATH_CONF_INIT

    # Add iBMC related exceptions
    # echo >> $PATH_COMMON_EXCEPTION
    # echo 'class IBMCError(IronicException):' >> $PATH_COMMON_EXCEPTION
    # echo '    _msg_fmt = _("IBMC exception occurred. Error: %(error)s")' >> $PATH_COMMON_EXCEPTION
    # echo >> $PATH_COMMON_EXCEPTION
    # echo >> $PATH_COMMON_EXCEPTION
    echo '

class IBMCError(IronicException):
    _msg_fmt = _("IBMC exception occurred. Error: %(error)s")


class IBMCConnectionError(IBMCError):
    _msg_fmt = _("IBMC connection failed for node %(node)s: %(error)s")
' >> $PATH_COMMON_EXCEPTION

    # Modify ironic egg info entry_points.txt
    INTERFACE_MGMT='ironic.hardware.interfaces.management'
    INTERFACE_POWER='ironic.hardware.interfaces.power'
    INTERFACE_VENDOR='ironic.hardware.interfaces.vendor'
    HARDWARE_TYPES='ironic.hardware.types'
    IBMC_MGMT='ibmc = ironic.drivers.modules.ibmc.management:IBMCManagement'
    IBMC_POWER='ibmc = ironic.drivers.modules.ibmc.power:IBMCPower'
    IBMC_VENDOR='ibmc = ironic.drivers.modules.ibmc.vendor:IBMCVendor'
    IBMC_HW_TYPE='ibmc = ironic.drivers.ibmc:IBMCHardware'
    sed -i$BAK_SUFFIX -r -e "s/(\[$INTERFACE_MGMT\])/\1\n$IBMC_MGMT/" $PATH_ENTRY_POINTS
    sed -i -r -e "s/(\[$INTERFACE_POWER\])/\1\n$IBMC_POWER/" $PATH_ENTRY_POINTS
    sed -i -r -e "s/(\[$INTERFACE_VENDOR\])/\1\n$IBMC_VENDOR/" $PATH_ENTRY_POINTS
    sed -i -r -e "s/(\[$HARDWARE_TYPES\])/\1\n$IBMC_HW_TYPE/" $PATH_ENTRY_POINTS

    echo "Patch done!"
}

# Undo patch function
function undo_patch {
    mv -f $PATH_CONF_INIT_BAK $PATH_CONF_INIT
    mv -f $PATH_COMMON_EXCEPTION_BAK $PATH_COMMON_EXCEPTION
    mv -f $PATH_ENTRY_POINTS_BAK $PATH_ENTRY_POINTS

    echo "Undo patch done!"
    return 0
}

# Usage
function usage {
    echo "Usage: `basename $0` [$IRONIC_REL_QUEENS|$IRONIC_REL_ROCKY] [patch|undo]"
    exit 1
}

# First argument is operation [patch|undo]
OP="${1}"
IRONIC_RELEASE="${2}"

if [[ "$IRONIC_RELEASE" != "$IRONIC_REL_QUEENS" || "$IRONIC_RELEASE" != "$IRONIC_REL_ROCKY" ]]
then
    usage
fi

if [ "$OP" == "patch" ]
then
    patch $IRONIC_RELEASE
elif [ "$OP" == "undo" ]
then
    undo_patch
else
    usage
fi

exit 0