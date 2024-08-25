#! /bin/bash

set -ex

JOBS=$1
DEBUG=$2
ZIP_NAME=$3
TRUST_VERIFICATION=$4
CA_NAME=$5

# Compile the cyb3rhq agent for Windows
FLAGS="-j ${JOBS} IMAGE_TRUST_CHECKS=${TRUST_VERIFICATION} CA_NAME=\"${CA_NAME}\" "

if [[ "${DEBUG}" = "yes" ]]; then
    FLAGS+="DEBUG=1 "
fi

if [ -z "${BRANCH}"]; then
    mkdir /cyb3rhq-local-src
    cp -r /local-src/* /cyb3rhq-local-src
else
    URL_REPO=https://github.com/cyb3rhq/cyb3rhq/archive/${BRANCH}.zip

    # Download the cyb3rhq repository
    wget -O cyb3rhq.zip ${URL_REPO} && unzip cyb3rhq.zip
fi

bash -c "make -C /cyb3rhq-*/src deps TARGET=winagent ${FLAGS}"
bash -c "make -C /cyb3rhq-*/src TARGET=winagent ${FLAGS}"

rm -rf /cyb3rhq-*/src/external

zip -r /shared/${ZIP_NAME} /cyb3rhq-*
