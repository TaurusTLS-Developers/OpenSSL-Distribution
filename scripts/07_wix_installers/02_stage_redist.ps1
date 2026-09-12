<#
.SYNOPSIS
    Job: 3c_wix-windows-installers | Step: 7 (Stage Redistributables & Convert LICENSE to RTF)
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

& "$env:COMMON_SCRIPTS_DIR\stage_windows_redist.ps1"