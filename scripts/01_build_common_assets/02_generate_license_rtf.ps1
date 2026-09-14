<#
.SYNOPSIS
    Converts plain-text LICENSE.txt into a cleanly formatted LICENSE.rtf for WiX MSI installers.
.DESCRIPTION
    Uses $env:COMMON_ASSETS_DIR or local directory conventions by default.
    Can be run without arguments in CI/local runner, or with explicit paths for testing.
.EXAMPLE
    pwsh ./02_generate_license_rtf.ps1
    pwsh ./02_generate_license_rtf.ps1 -InputPath "my_license.txt"
#>
[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

try {
    # 1. Resolve InputPath using Environment Variables & Smart Fallbacks
    if (-not $InputPath) {
        $commonAssets = $env:COMMON_ASSETS_DIR ?? (Join-Path ($env:GITHUB_WORKSPACE ?? $PWD.Path) "common-assets")
        
        $candidates = @(
            (Join-Path $commonAssets "usr\local\LICENSE.txt"),
            (Join-Path $commonAssets "LICENSE.txt"),
            (Join-Path $PWD.Path "LICENSE.txt")
        )

        $InputPath = $candidates | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
        if (-not $InputPath) {
            throw "LICENSE.txt not found! Checked locations:`n - $($candidates -join "`n - ")"
        }
    }

    # Ensure InputPath is an absolute path
    if (-not [System.IO.Path]::IsPathRooted($InputPath)) {
        $InputPath = Join-Path $PWD.Path $InputPath
    }

    # 2. OutputPath automatically mirrors InputPath as .rtf if not specified
    if (-not $OutputPath) {
        $OutputPath = [System.IO.Path]::ChangeExtension($InputPath, ".rtf")
    } elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath = Join-Path $PWD.Path $OutputPath
    }

    Write-Host "[RTF-CONVERT] Source:      $InputPath"
    Write-Host "[RTF-CONVERT] Destination: $OutputPath"

    # 3. Verify source file has content
    $rawText = [System.IO.File]::ReadAllText($InputPath)
    if ([string]::IsNullOrWhiteSpace($rawText)) {
        throw "Input license file '$InputPath' is empty!"
    }

    $lines = $rawText -split "`r?`n"

    # 4. Extract Title block (skipping any leading blank lines)
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
        throw "Failed to parse title block: No content found in '$InputPath'"
    }

    # 5. Group body paragraphs (concatenating lines between empty lines)
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

    # 6. Build RTF document
    $rtf = "{\rtf1\ansi\ansicpg1252\deff0\nouicompat\deflang1033{\fonttbl{\f0\fnil\fcharset0 Segoe UI;}}`r`n"
    
    # Title: Centered, Bold
    $titleContent = ($titleLines | ForEach-Object { "$_ \line " }) -join ""
    $titleContent = $titleContent -replace ' \\line $', ''
    $rtf += "\pard\qc\b\fs22 $titleContent\b0\par\par`r`n"

    # Body Paragraphs: Left-aligned (Section headers centered)
    foreach ($block in $bodyBlocks) {
        if ($block -cmatch '^[A-Z\s,.:\-]+$' -and $block -cmatch '[A-Z]' -and $block.Length -lt 100) {
            $rtf += "\pard\qc\b\fs20 $block\b0\par\par`r`n"
        } else {
            $rtf += "\pard\ql\fs18 $block\par\par`r`n"
        }
    }
    $rtf += "}"

    # Ensure output folder exists
    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }

    [System.IO.File]::WriteAllText($OutputPath, $rtf, [System.Text.Encoding]::ASCII)
    Write-Host "✅ Generated formatted RTF: '$OutputPath'"
}
catch {
    Write-Error "FATAL: $($_.Exception.Message)"
    exit 1
}
