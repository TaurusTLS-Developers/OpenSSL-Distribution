<#
.SYNOPSIS
    Job: 3a_innosetup-windows-installer | Step: 7 (Stage Multi-Arch Redistributables)
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

& "$env:COMMON_SCRIPTS_DIR\stage_windows_redist.ps1"