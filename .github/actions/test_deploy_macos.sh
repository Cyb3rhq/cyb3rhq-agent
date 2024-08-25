#!/bin/bash

# Copyright (C) 2015, Cyb3rhq Inc.
#
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

# Global variables
VERSION="$(sed 's/v//' src/VERSION)"
MAJOR=$(echo "${VERSION}" | cut -dv -f2 | cut -d. -f1)
MINOR=$(echo "${VERSION}" | cut -d. -f2)
SHA="$(git rev-parse --short=7 "$1")"

CYB3RHQ_MACOS_AGENT_DEPLOYMENT_VARS="/tmp/cyb3rhq_envs"
conf_path="/Library/Ossec/etc/ossec.conf"

VARS=( "CYB3RHQ_MANAGER" "CYB3RHQ_MANAGER_PORT" "CYB3RHQ_PROTOCOL" "CYB3RHQ_REGISTRATION_SERVER" "CYB3RHQ_REGISTRATION_PORT" "CYB3RHQ_REGISTRATION_PASSWORD" "CYB3RHQ_KEEP_ALIVE_INTERVAL" "CYB3RHQ_TIME_RECONNECT" "CYB3RHQ_REGISTRATION_CA" "CYB3RHQ_REGISTRATION_CERTIFICATE" "CYB3RHQ_REGISTRATION_KEY" "CYB3RHQ_AGENT_NAME" "CYB3RHQ_AGENT_GROUP" "ENROLLMENT_DELAY" )
VALUES=( "1.1.1.1" "7777" "udp" "2.2.2.2" "8888" "password" "10" "10" "/Library/Ossec/etc/testsslmanager.cert" "/Library/Ossec/etc/testsslmanager.cert" "/Library/Ossec/etc/testsslmanager.key" "test-agent" "test-group" "10" )
TAGS1=( "<address>" "<port>" "<protocol>" "<manager_address>" "<port>" "<password>" "<notify_time>" "<time-reconnect>" "<server_ca_path>" "<agent_certificate_path>" "<agent_key_path>" "<agent_name>" "<groups>" "<delay_after_enrollment>" )
TAGS2=( "</address>" "</port>" "</protocol>" "</manager_address>" "</port>" "</password>" "</notify_time>" "</time-reconnect>" "</server_ca_path>" "</agent_certificate_path>" "</agent_key_path>" "</agent_name>" "</groups>" "</delay_after_enrollment>" )
CYB3RHQ_REGISTRATION_PASSWORD_PATH="/Library/Ossec/etc/authd.pass"

function install_cyb3rhq(){

  echo "Testing the following variables $1"

  eval "echo \"$1\" > ${CYB3RHQ_MACOS_AGENT_DEPLOYMENT_VARS} && installer -pkg cyb3rhq-agent-${VERSION}-0.commit${SHA}.pkg -target / > /dev/null 2>&1"
  
}

function remove_cyb3rhq () {

  /bin/rm -r /Library/Ossec > /dev/null 2>&1
  /bin/launchctl unload /Library/LaunchDaemons/com.cyb3rhq.agent.plist > /dev/null 2>&1
  /bin/rm -f /Library/LaunchDaemons/com.cyb3rhq.agent.plist > /dev/null 2>&1
  /bin/rm -rf /Library/StartupItems/CYB3RHQ > /dev/null 2>&1
  /usr/bin/dscl . -delete "/Users/cyb3rhq" > /dev/null 2>&1
  /usr/bin/dscl . -delete "/Groups/cyb3rhq" > /dev/null 2>&1
  /usr/sbin/pkgutil --forget com.cyb3rhq.pkg.cyb3rhq-agent > /dev/null 2>&1

}

function test() {

  for i in "${!VARS[@]}"; do
    if ( echo "${@}" | grep -q -w "${VARS[i]}" ); then
      if [ "${VARS[i]}" == "CYB3RHQ_MANAGER" ] || [ "${VARS[i]}" == "CYB3RHQ_PROTOCOL" ]; then
        LIST=( "${VALUES[i]//,/ }" )
        for j in "${!LIST[@]}"; do
          if ( grep -q "${TAGS1[i]}${LIST[j]}${TAGS2[i]}" "${conf_path}" ); then
            echo "The variable ${VARS[i]} is set correctly"
          else
            echo "The variable ${VARS[i]} is not set correctly"
            exit 1
          fi
        done
      elif [ "${VARS[i]}" == "CYB3RHQ_REGISTRATION_PASSWORD" ]; then
        if ( grep -q "${VALUES[i]}" "${CYB3RHQ_REGISTRATION_PASSWORD_PATH}" ); then
          echo "The variable ${VARS[i]} is set correctly"
        else
          echo "The variable ${VARS[i]} is not set correctly"
          exit 1
        fi
      else
        if ( grep -q "${TAGS1[i]}${VALUES[i]}${TAGS2[i]}" "${conf_path}" ); then
          echo "The variable ${VARS[i]} is set correctly"
        else
          echo "The variable ${VARS[i]} is not set correctly"
          exit 1
        fi
      fi
    fi
  done

}

echo "Download package https://s3.us-west-1.amazonaws.com/packages-dev.wazuh.com/warehouse/pullrequests/${MAJOR}.${MINOR}/macos/cyb3rhq-agent-${VERSION}-0.commit${SHA}.pkg"
wget "https://s3.us-west-1.amazonaws.com/packages-dev.wazuh.com/warehouse/pullrequests/${MAJOR}.${MINOR}/macos/cyb3rhq-agent-${VERSION}-0.commit${SHA}.pkg" > /dev/null 2>&1

install_cyb3rhq "CYB3RHQ_MANAGER='1.1.1.1' && CYB3RHQ_MANAGER_PORT='7777' && CYB3RHQ_PROTOCOL='udp' && CYB3RHQ_REGISTRATION_SERVER='2.2.2.2' && CYB3RHQ_REGISTRATION_PORT='8888' && CYB3RHQ_REGISTRATION_PASSWORD='password' && CYB3RHQ_KEEP_ALIVE_INTERVAL='10' && CYB3RHQ_TIME_RECONNECT='10' && CYB3RHQ_REGISTRATION_CA='/Library/Ossec/etc/testsslmanager.cert' && CYB3RHQ_REGISTRATION_CERTIFICATE='/Library/Ossec/etc/testsslmanager.cert' && CYB3RHQ_REGISTRATION_KEY='/Library/Ossec/etc/testsslmanager.key' && CYB3RHQ_AGENT_NAME='test-agent' && CYB3RHQ_AGENT_GROUP='test-group' && ENROLLMENT_DELAY='10'" 
test "CYB3RHQ_MANAGER CYB3RHQ_MANAGER_PORT CYB3RHQ_PROTOCOL CYB3RHQ_REGISTRATION_SERVER CYB3RHQ_REGISTRATION_PORT CYB3RHQ_REGISTRATION_PASSWORD CYB3RHQ_KEEP_ALIVE_INTERVAL CYB3RHQ_TIME_RECONNECT CYB3RHQ_REGISTRATION_CA CYB3RHQ_REGISTRATION_CERTIFICATE CYB3RHQ_REGISTRATION_KEY CYB3RHQ_AGENT_NAME CYB3RHQ_AGENT_GROUP ENROLLMENT_DELAY" 
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_MANAGER='1.1.1.1'"
test "CYB3RHQ_MANAGER"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_MANAGER_PORT='7777'"
test "CYB3RHQ_MANAGER_PORT"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_PROTOCOL='udp'"
test "CYB3RHQ_PROTOCOL"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_SERVER='2.2.2.2'"
test "CYB3RHQ_REGISTRATION_SERVER"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_PORT='8888'"
test "CYB3RHQ_REGISTRATION_PORT"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_PASSWORD='password'"
test "CYB3RHQ_REGISTRATION_PASSWORD"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_KEEP_ALIVE_INTERVAL='10'"
test "CYB3RHQ_KEEP_ALIVE_INTERVAL"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_TIME_RECONNECT='10'"
test "CYB3RHQ_TIME_RECONNECT"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_CA='/Library/Ossec/etc/testsslmanager.cert'"
test "CYB3RHQ_REGISTRATION_CA"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_CERTIFICATE='/Library/Ossec/etc/testsslmanager.cert'"
test "CYB3RHQ_REGISTRATION_CERTIFICATE"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_KEY='/Library/Ossec/etc/testsslmanager.key'"
test "CYB3RHQ_REGISTRATION_KEY"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_AGENT_NAME='test-agent'"
test "CYB3RHQ_AGENT_NAME"
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_AGENT_GROUP='test-group'"
test "CYB3RHQ_AGENT_GROUP"
remove_cyb3rhq

install_cyb3rhq "ENROLLMENT_DELAY='10'"
test "ENROLLMENT_DELAY"
remove_cyb3rhq
