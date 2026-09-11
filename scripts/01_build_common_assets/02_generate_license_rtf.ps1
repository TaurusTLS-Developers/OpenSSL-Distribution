<#
.SYNOPSIS
    Job: 1_build-common-assets | Step: 4 (Generate Formatted LICENSE.rtf for WiX MSI)
    Converts plain-text LICENSE.txt into formatted RTF for WiX MSI installers.
.PARAMETER InputPath
    Path to plain-text LICENSE.txt file.
.PARAMETER OutputPath
    Path for generated LICENSE.rtf file.
#>
[CmdletBinding()]
param(
    [string]$InputPath = "common-assets/usr/local/LICENSE.txt",
    [string]$OutputPath = "common-assets/usr/local/LICENSE.rtf"
)

$ErrorActionPreference = 'Stop'

try {
    if (-not [System.IO.Path]::IsPathRooted($InputPath)) {
        $InputPath = Join-Path $PWD.Path $InputPath
    }
    if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath = Join-Path $PWD.Path $OutputPath
    }

    if (-not (Test-Path -Path $InputPath -PathType Leaf)) {
        throw "Input license file was not found at path: '$InputPath'"
    }

    $rawText = [System.IO.File]::ReadAllText($InputPath)
    if ([string]::IsNullOrWhiteSpace($rawText)) {
        throw "Input license file '$InputPath' is empty!"
    }

    $lines = $rawText -split "`r?`n"

    $titleLines = [System.Collections.Generic.List[string]]::new()
    $titleStarted = $false
    $bodyStartIndex = $lines.Length

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $trimmed = $lines[$i].Trim()
        if (-not $titleStarted) {
            if ($trimmed.Length -gt 0) {
                $titleStarted = $true
                $titleLines.Add($trimmed)
            }
        } else {
            if ($trimmed.Length -eq 0) {
                $bodyStartIndex = $i
                break
            }
            $titleLines.Add($trimmed)
        }
    }

    if ($titleLines.Count -eq 0) {
        throw "Failed to parse title block: No non-empty lines found in '$InputPath'"
    }

    $bodyLines = if ($bodyStartIndex -lt $lines.Length) { $lines[$bodyStartIndex..($lines.Length - 1)] } else { @() }
    $bodyBlocks = [System.Collections.Generic.List[string]]::new()
    $currentBlock = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $bodyLines) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -gt 0) {
            $currentBlock.Add($trimmed)
        } else {
            if ($currentBlock.Count -gt 0) {
                $bodyBlocks.Add(($currentBlock -join " "))
                $currentBlock.Clear()
            }
        }
    }
    if ($currentBlock.Count -gt 0) {
        $bodyBlocks.Add(($currentBlock -join " "))
    }

    $rtf = "{\rtf1\ansi\ansicpg1252\deff0\nouicompat\deflang1033{\fonttbl{\f0\fnil\fcharset0 Segoe UI;}}`r`n"
    $titleContent = ($titleLines | ForEach-Object { "$_ \line " }) -join ""
    $titleContent = $titleContent -replace ' \\line $', ''
    $rtf += "\pard\qc\b\fs22 $titleContent\b0\par\par`r`n"

    foreach ($block in $bodyBlocks) {
        if ($block -cmatch '^[A-Z\s,.:\-]+$' -and $block -cmatch '[A-Z]' -and $block.Length -lt 100) {
            $rtf += "\pard\qc\b\fs20 $block\b0\par\par`r`n"
        } else {
            $rtf += "\pard\ql\fs18 $block\par\par`r`n"
        }
    }
    $rtf += "}"

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }

    [System.IO.File]::WriteAllText($OutputPath, $rtf, [System.Text.Encoding]::ASCII)
    Write-Host "[LICENSE-RTF] ✅ Successfully generated formatted RTF: '$OutputPath'"
}
catch {
    Write-Error "[LICENSE-RTF] FATAL: $($_.Exception.Message)"
    exit 1
}
