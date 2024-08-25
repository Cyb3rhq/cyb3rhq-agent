# Created by Cyb3rhq, Inc. <info@wazuh.com>.
# This program is a free software; you can redistribute it and/or modify it under the terms of GPLv2

param (
    [string]$MSI_NAME = "cyb3rhq-agent.msi",
    [string]$SIGN = "no",
    [string]$WIX_TOOLS_PATH = "",
    [string]$SIGN_TOOLS_PATH = "",
    [switch]$help
    )

$CANDLE_EXE = "candle.exe"
$LIGHT_EXE = "light.exe"
$SIGNTOOL_EXE = "signtool.exe"

if(($help.isPresent)) {
    "
    This tool can be used to generate the Windows Cyb3rhq agent msi package.

    PARAMETERS TO BUILD CYB3RHQ-AGENT MSI (OPTIONALS):
        1. MSI_NAME: MSI package name output.
        2. SIGN: yes or no. By default 'no'.
        3. WIX_TOOLS_PATH: Wix tools path.
        4. SIGN_TOOLS_PATH: sign tools path.

    USAGE:

        * CYB3RHQ:
          $ ./generate_cyb3rhq_msi.ps1  -MSI_NAME {{ NAME }} -SIGN {{ yes|no }} -WIX_TOOLS_PATH {{ PATH }} -SIGN_TOOLS_PATH {{ PATH }}

            Build a devel msi:    $ ./generate_cyb3rhq_msi.ps1 -MSI_NAME cyb3rhq-agent_4.9.0-0_windows_0ceb378.msi -SIGN no
            Build a prod msi:     $ ./generate_cyb3rhq_msi.ps1 -MSI_NAME cyb3rhq-agent-4.9.0-1.msi -SIGN yes
    "
    Exit
}

# Get Power Shell version.
$PSversion = $PSVersionTable.PSVersion.Major
if ($PSversion -eq $null) {
    $PSversion = 1 # $PSVersionTable is new with Powershell 2.0
}

function BuildCyb3rhqMsi(){
    Write-Host "MSI_NAME = $MSI_NAME"

    if($WIX_TOOLS_PATH -ne ""){
        $CANDLE_EXE = $WIX_TOOLS_PATH + "/" + $CANDLE_EXE
        $LIGHT_EXE = $WIX_TOOLS_PATH + "/" + $LIGHT_EXE
    }

    if($SIGN_TOOLS_PATH -ne ""){
        $SIGNTOOL_EXE = $SIGN_TOOLS_PATH + "/" + $SIGNTOOL_EXE
    }

    if($SIGN -eq "yes"){
        # Sign .exe files and the InstallerScripts.vbs
        Write-Host "Signing .exe files..."
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 ".\*.exe"
        Write-Host "Signing .vbs files..."
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 ".\InstallerScripts.vbs"
        Write-Host "Signing .dll files..."
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 "..\*.dll"
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 ".\*.dll"
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 "..\data_provider\build\bin\sysinfo.dll"
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 "..\shared_modules\dbsync\build\bin\dbsync.dll"
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 "..\shared_modules\rsync\build\bin\rsync.dll"
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 "..\cyb3rhq_modules\syscollector\build\bin\syscollector.dll"
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /fd SHA256 /td SHA256 "..\syscheckd\build\bin\libfimdb.dll"
    }

    Write-Host "Building MSI installer..."

    & $CANDLE_EXE -nologo .\cyb3rhq-installer.wxs -out "cyb3rhq-installer.wixobj" -ext WixUtilExtension -ext WixUiExtension
    & $LIGHT_EXE ".\cyb3rhq-installer.wixobj" -out $MSI_NAME -ext WixUtilExtension -ext WixUiExtension

    if($SIGN -eq "yes"){
        Write-Host "Signing $MSI_NAME..."
        & $SIGNTOOL_EXE sign /a /tr http://timestamp.digicert.com /d $MSI_NAME /fd SHA256 /td SHA256 $MSI_NAME
    }
}

############################
# MAIN
############################

BuildCyb3rhqMsi
