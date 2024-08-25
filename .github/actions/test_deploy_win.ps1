# Copyright (C) 2015, Cyb3rhq Inc.
#
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

$VERSION = Get-Content src/VERSION
[version]$VERSION = $VERSION -replace '[v]',''
$MAJOR=$VERSION.Major
$MINOR=$VERSION.Minor
$SHA= git rev-parse --short $args[0]

$TEST_ARRAY=@( 
              @("CYB3RHQ_MANAGER ", "1.1.1.1", "<address>", "</address>"), 
              @("CYB3RHQ_MANAGER_PORT ", "7777", "<port>", "</port>"),
              @("CYB3RHQ_PROTOCOL ", "udp", "<protocol>", "</protocol>"),
              @("CYB3RHQ_REGISTRATION_SERVER ", "2.2.2.2", "<manager_address>", "</manager_address>"),
              @("CYB3RHQ_REGISTRATION_PORT ", "8888", "<port>", "</port>"),
              @("CYB3RHQ_REGISTRATION_PASSWORD ", "password", "<password>", "</password>"),
              @("CYB3RHQ_KEEP_ALIVE_INTERVAL ", "10", "<notify_time>", "</notify_time>"),
              @("CYB3RHQ_TIME_RECONNECT ", "10", "<time-reconnect>", "</time-reconnect>"),
              @("CYB3RHQ_REGISTRATION_CA ", "/var/ossec/etc/testsslmanager.cert", "<server_ca_path>", "</server_ca_path>"),
              @("CYB3RHQ_REGISTRATION_CERTIFICATE ", "/var/ossec/etc/testsslmanager.cert", "<agent_certificate_path>", "</agent_certificate_path>"),
              @("CYB3RHQ_REGISTRATION_KEY ", "/var/ossec/etc/testsslmanager.key", "<agent_key_path>", "</agent_key_path>"),
              @("CYB3RHQ_AGENT_NAME ", "test-agent", "<agent_name>", "</agent_name>"),
              @("CYB3RHQ_AGENT_GROUP ", "test-group", "<groups>", "</groups>"),
              @("ENROLLMENT_DELAY ", "10", "<delay_after_enrollment>", "</delay_after_enrollment>")
)

function install_cyb3rhq($vars)
{

    Write-Output "Testing the following variables $vars"
    Start-Process  C:\Windows\System32\msiexec.exe -ArgumentList  "/i cyb3rhq-agent-$VERSION-0.commit$SHA.msi /qn $vars" -wait
    
}

function remove_cyb3rhq
{

    Start-Process  C:\Windows\System32\msiexec.exe -ArgumentList "/x cyb3rhq-agent-$VERSION-commit$SHA.msi /qn" -wait

}

function test($vars)
{

  For ($i=0; $i -lt $TEST_ARRAY.Length; $i++) {
    if($vars.Contains($TEST_ARRAY[$i][0])) {
      if ( ($TEST_ARRAY[$i][0] -eq "CYB3RHQ_MANAGER ") -OR ($TEST_ARRAY[$i][0] -eq "CYB3RHQ_PROTOCOL ") ) {
        $LIST = $TEST_ARRAY[$i][1].split(",")
        For ($j=0; $j -lt $LIST.Length; $j++) {
          $SEL = Select-String -Path 'C:\Program Files (x86)\ossec-agent\ossec.conf' -Pattern "$($TEST_ARRAY[$i][2])$($LIST[$j])$($TEST_ARRAY[$i][3])"
          if($SEL -ne $null) {
            Write-Output "The variable $($TEST_ARRAY[$i][0]) is set correctly"
          }
          if($SEL -eq $null) {
            Write-Output "The variable $($TEST_ARRAY[$i][0]) is not set correctly"
            exit 1
          }
        }
      }
      ElseIf ( ($TEST_ARRAY[$i][0] -eq "CYB3RHQ_REGISTRATION_PASSWORD ") ) {
        if (Test-Path 'C:\Program Files (x86)\ossec-agent\authd.pass'){
          $SEL = Select-String -Path 'C:\Program Files (x86)\ossec-agent\authd.pass' -Pattern "$($TEST_ARRAY[$i][1])"
          if($SEL -ne $null) {
            Write-Output "The variable $($TEST_ARRAY[$i][0]) is set correctly"
          }
          if($SEL -eq $null) {
            Write-Output "The variable $($TEST_ARRAY[$i][0]) is not set correctly"
            exit 1
          }
        }
        else
        {
          Write-Output "CYB3RHQ_REGISTRATION_PASSWORD is not correct"
          exit 1
        }
      }
      Else {
        $SEL = Select-String -Path 'C:\Program Files (x86)\ossec-agent\ossec.conf' -Pattern "$($TEST_ARRAY[$i][2])$($TEST_ARRAY[$i][1])$($TEST_ARRAY[$i][3])"
        if($SEL -ne $null) {
          Write-Output "The variable $($TEST_ARRAY[$i][0]) is set correctly"
        }
        if($SEL -eq $null) {
          Write-Output "The variable $($TEST_ARRAY[$i][0]) is not set correctly"
          exit 1
        }
      }
    }
  }

}

Write-Output "Download package: https://s3.us-west-1.amazonaws.com/packages-dev.wazuh.com/warehouse/pullrequests/$MAJOR.$MINOR/windows/cyb3rhq-agent-$VERSION-0.commit$SHA.msi"
Invoke-WebRequest -Uri "https://s3.us-west-1.amazonaws.com/packages-dev.wazuh.com/warehouse/pullrequests/$MAJOR.$MINOR/windows/cyb3rhq-agent-$VERSION-0.commit$SHA.msi" -OutFile "cyb3rhq-agent-$VERSION-0.commit$SHA.msi"

install_cyb3rhq "CYB3RHQ_MANAGER=1.1.1.1 CYB3RHQ_MANAGER_PORT=7777 CYB3RHQ_PROTOCOL=udp CYB3RHQ_REGISTRATION_SERVER=2.2.2.2 CYB3RHQ_REGISTRATION_PORT=8888 CYB3RHQ_REGISTRATION_PASSWORD=password CYB3RHQ_KEEP_ALIVE_INTERVAL=10 CYB3RHQ_TIME_RECONNECT=10 CYB3RHQ_REGISTRATION_CA=/var/ossec/etc/testsslmanager.cert CYB3RHQ_REGISTRATION_CERTIFICATE=/var/ossec/etc/testsslmanager.cert CYB3RHQ_REGISTRATION_KEY=/var/ossec/etc/testsslmanager.key CYB3RHQ_AGENT_NAME=test-agent CYB3RHQ_AGENT_GROUP=test-group ENROLLMENT_DELAY=10" 
test "CYB3RHQ_MANAGER CYB3RHQ_MANAGER_PORT CYB3RHQ_PROTOCOL CYB3RHQ_REGISTRATION_SERVER CYB3RHQ_REGISTRATION_PORT CYB3RHQ_REGISTRATION_PASSWORD CYB3RHQ_KEEP_ALIVE_INTERVAL CYB3RHQ_TIME_RECONNECT CYB3RHQ_REGISTRATION_CA CYB3RHQ_REGISTRATION_CERTIFICATE CYB3RHQ_REGISTRATION_KEY CYB3RHQ_AGENT_NAME CYB3RHQ_AGENT_GROUP ENROLLMENT_DELAY " 
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_MANAGER=1.1.1.1"
test "CYB3RHQ_MANAGER "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_MANAGER_PORT=7777"
test "CYB3RHQ_MANAGER_PORT "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_PROTOCOL=udp"
test "CYB3RHQ_PROTOCOL "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_SERVER=2.2.2.2"
test "CYB3RHQ_REGISTRATION_SERVER "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_PORT=8888"
test "CYB3RHQ_REGISTRATION_PORT "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_PASSWORD=password"
test "CYB3RHQ_REGISTRATION_PASSWORD "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_KEEP_ALIVE_INTERVAL=10"
test "CYB3RHQ_KEEP_ALIVE_INTERVAL "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_TIME_RECONNECT=10"
test "CYB3RHQ_TIME_RECONNECT "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_CA=/var/ossec/etc/testsslmanager.cert"
test "CYB3RHQ_REGISTRATION_CA "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_CERTIFICATE=/var/ossec/etc/testsslmanager.cert"
test "CYB3RHQ_REGISTRATION_CERTIFICATE "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_REGISTRATION_KEY=/var/ossec/etc/testsslmanager.key"
test "CYB3RHQ_REGISTRATION_KEY "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_AGENT_NAME=test-agent"
test "CYB3RHQ_AGENT_NAME "
remove_cyb3rhq

install_cyb3rhq "CYB3RHQ_AGENT_GROUP=test-group"
test "CYB3RHQ_AGENT_GROUP "
remove_cyb3rhq

install_cyb3rhq "ENROLLMENT_DELAY=10"
test "ENROLLMENT_DELAY "
remove_cyb3rhq
