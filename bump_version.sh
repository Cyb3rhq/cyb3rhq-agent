#!/bin/bash

# Bump source version
# Copyright (C) 2015, Cyb3rhq Inc.
# May 2, 2017

# Syntax:
# bump_version [ <version> ] [ -r <revision> ] [ -p <product_version> ]
# Example:
# ./bump_version.sh v3.0.0-alpha1 -r 3457 -p 3.0.0.1

while [ -n "$1" ]
do
    case $1 in
    "-p")
        if [[ $2 =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$ ]]
        then
            product=$2
        else
            echo "Error: product does not match 'X.X.X.X'"
            exit 1
        fi

        shift 2
        ;;
    "-r")
        if [[ $2 =~ ^[[:digit:]]+$ ]]
        then
            revision=$2
        else
            echo "Error: revision is not numeric."
            exit 1
        fi

        shift 2
        ;;
    *)
        if [[ $1 =~ ^v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+(-[[:alnum:]]+)?$ ]]
        then
            version=$1
        else
            echo "Error: incorrect version (must have form 'vX.X.X' or 'vX.X.X-...')."
            exit 1
        fi

        shift 1
    esac
done

if [ -z "$version" ] && [ -z "$revision" ] && [ -z "$product" ]
then
    echo "Error: no arguments given."
    echo "Syntax: $0 [ <version> ] [ -r <revision> ] [ -p <product_version> ]"
    exit 1
fi

cd $(dirname $0)

VERSION_FILE="../src/VERSION"
REVISION_FILE="../src/REVISION"
DEFS_FILE="../src/headers/defs.h"
CYB3RHQ_SERVER="../src/init/cyb3rhq-server.sh"
CYB3RHQ_AGENT="../src/init/cyb3rhq-client.sh"
CYB3RHQ_LOCAL="../src/init/cyb3rhq-local.sh"
NSIS_FILE="../src/win32/cyb3rhq-installer.nsi"
MSI_FILE="../src/win32/cyb3rhq-installer.wxs"
FW_INIT="../framework/cyb3rhq/__init__.py"
CLUSTER_INIT="../framework/cyb3rhq/core/cluster/__init__.py"
API_SETUP="../api/setup.py"
API_SPEC="../api/api/spec/spec.yaml"
VERSION_DOCU="../src/Doxyfile"
WIN_RESOURCE="../src/win32/version.rc"

if [ -n "$version" ]
then

    # File VERSIONS

    echo $version > $VERSION_FILE

    # File defs.h

    egrep "^#define __ossec_version +\"v.+\"" $DEFS_FILE > /dev/null

    if [ $? != 0 ]
    then
        echo "Error: no suitable version definition found at file $DEFS_FILE"
        exit 1
    fi

    sed -E -i'' -e "s/^(#define __ossec_version +)\"v.*\"/\1\"$version\"/" $DEFS_FILE

    # cyb3rhq-control

    sed -E -i'' -e "s/^(VERSION=+)\"v.*\"/\1\"$version\"/" $CYB3RHQ_SERVER
    sed -E -i'' -e "s/^(VERSION=+)\"v.*\"/\1\"$version\"/" $CYB3RHQ_AGENT
    sed -E -i'' -e "s/^(VERSION=+)\"v.*\"/\1\"$version\"/" $CYB3RHQ_LOCAL

    # File cyb3rhq-installer.nsi

    egrep "^\!define VERSION \".+\"" $NSIS_FILE > /dev/null

    if [ $? != 0 ]
    then
        echo "Error: no suitable version definition found at file $NSIS_FILE"
        exit 1
    fi

    sed -E -i'' -e "s/^(\!define VERSION \").+\"/\1${version:1}\"/g" $NSIS_FILE

    # File cyb3rhq-installer.wxs

    egrep '<Product Id="\*" Name="Cyb3rhq Agent" Language="1033" Version=".+" Manufacturer=' $MSI_FILE > /dev/null

    if [ $? != 0 ]
    then
        echo "Error: no suitable version definition found at file $MSI_FILE"
        exit 1
    fi

    sed -E -i'' -e "s/(<Product Id=\"\*\" Name=\"Cyb3rhq Agent\" Language=\"1033\" Version=\").+(\" Manufacturer=)/\1${version:1}\2/g" $MSI_FILE

    # Framework

    sed -E -i'' -e "s/__version__ = '.+'/__version__ = '${version:1}'/g" $FW_INIT

    # Cluster

    sed -E -i'' -e "s/__version__ = '.+'/__version__ = '${version:1}'/g" $CLUSTER_INIT

    # API

    sed -E -i'' -e "s/version='.+',/version='${version:1}',/g" $API_SETUP
    sed -E -i'' -e "s/version: '.+'/version: '${version:1}'/g" $API_SPEC
    sed -E -i'' -e "s_/v[0-9]+\.[0-9]+\.[0-9]+_/${version}_g" $API_SPEC
    sed -E -i'' -e "s_com/[0-9]+\.[0-9]+_com/$(expr match "$version" 'v\([0-9]*.[0-9]*\).*')_g" $API_SPEC

    # Documentation config file

    sed -E -i'' -e "s/PROJECT_NUMBER         = \".+\"/PROJECT_NUMBER         = \"$version\"/g" $VERSION_DOCU

    # version.rc

    egrep "^#define VER_PRODUCTVERSION_STR v.+" $WIN_RESOURCE > /dev/null

    if [ $? != 0 ]
    then
        echo "Error: no suitable version definition (VER_PRODUCTVERSION_STR) found at file $WIN_RESOURCE"
        exit 1
    fi

    sed -E -i'' -e "s/^(#define VER_PRODUCTVERSION_STR +)v.+/\1$version/" $WIN_RESOURCE

    egrep "^#define VER_PRODUCTVERSION [[:digit:]]+,[[:digit:]]+,[[:digit:]]+,[[:digit:]]+" $WIN_RESOURCE > /dev/null

    if [ $? != 0 ]
    then
        echo "Error: no suitable version definition (VER_PRODUCTVERSION) found at file $WIN_RESOURCE"
        exit 1
    fi

    product_commas=`echo "${version:1}.0" | tr '.' ','`
    sed -E -i'' -e "s/^(#define VER_PRODUCTVERSION +).+/\1$product_commas/" $WIN_RESOURCE
fi

if [ -n "$revision" ]
then
    CURRENT_VERSION=$(cat $VERSION_FILE)

    # File REVISION

    echo $revision > $REVISION_FILE

    # cyb3rhq-control

    sed -E -i'' -e "s/^(REVISION=+)\".*\"/\1\"$revision\"/" $CYB3RHQ_SERVER
    sed -E -i'' -e "s/^(REVISION=+)\".*\"/\1\"$revision\"/" $CYB3RHQ_AGENT
    sed -E -i'' -e "s/^(REVISION=+)\".*\"/\1\"$revision\"/" $CYB3RHQ_LOCAL

    # File cyb3rhq-installer.nsi

    egrep "^\!define REVISION \".+\"" $NSIS_FILE > /dev/null

    if [ $? != 0 ]
    then
        echo "Error: no suitable revision definition found at file $NSIS_FILE"
        exit 1
    fi

    sed -E -i'' -e "s/^(\!define REVISION \").+\"/\1$revision\"/g" $NSIS_FILE

    # Cluster

    sed -E -i'' -e "s/__revision__ = '.+'/__revision__ = '$revision'/g" $CLUSTER_INIT

    # API

    sed -E -i'' -e "s/x-revision: .+'/x-revision: '$revision'/g" $API_SPEC

    # Documentation config file

    sed -E -i'' -e "s/PROJECT_NUMBER         = \".+\"/PROJECT_NUMBER         = \"$CURRENT_VERSION-$revision\"/g" $VERSION_DOCU
fi

if [ -n "$product" ]
then

    # File cyb3rhq-installer.nsi

    egrep "^VIProductVersion \".+\"" $NSIS_FILE > /dev/null

    if [ $? != 0 ]
    then
        echo "Error: no suitable product definition found at file $NSIS_FILE"
        exit 1
    fi

    sed -E -i'' -e "s/^(VIProductVersion \").+\"/\1$product\"/g" $NSIS_FILE
fi
