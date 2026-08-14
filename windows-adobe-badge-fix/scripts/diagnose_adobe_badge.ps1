<#
.SYNOPSIS
  Diagnose missing Adobe software badges on .psd/.ai files in Windows Explorer.

.DESCRIPTION
  Checks all relevant registry keys for .psd and .ai file associations,
  installed Adobe products, Icaros thumbnail provider configuration, and
  UserChoice overrides. Outputs a structured report to %TEMP%\adobe_badge_report.txt.

.PARAMETER Extension
  File extension to diagnose (default: .psd). Can also specify .ai or both.

.EXAMPLE
  .\diagnose_adobe_badge.ps1
  .\diagnose_adobe_badge.ps1 -Extension .ai
  .\diagnose_adobe_badge.ps1 -Extension .psd,.ai
#>

param(
    [string[]]$Extension = @(".psd", ".ai")
)

$reportPath = "$env:TEMP\adobe_badge_report.txt"

function Write-Report($text) {
    $text | Out-File $reportPath -Append -Encoding utf8
}

# Clear previous report
"" | Out-File $reportPath -Encoding utf8

Write-Report "============================================"
Write-Report "  Adobe Badge Diagnostic Report"
Write-Report "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Report "============================================"
Write-Report ""

# --- Section 1: Installed Adobe Products ---
Write-Report "=== 1. Installed Adobe Products ==="
$adobeDirs = @(
    "C:\Program Files\Adobe",
    "C:\Program Files (x86)\Adobe"
)
foreach ($dir in $adobeDirs) {
    if (Test-Path $dir) {
        Write-Report "[Found] $dir"
        Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $exe = Get-ChildItem $_.FullName -Filter "*.exe" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "Photoshop|Illustrator" } |
                Select-Object -First 1
            if ($exe) {
                Write-Report "  $($_.Name) -> $($exe.FullName)"
            } else {
                Write-Report "  $($_.Name)"
            }
        }
    } else {
        Write-Report "[Not Found] $dir"
    }
}
Write-Report ""

# --- Section 2: Photoshop Registry Version ---
Write-Report "=== 2. Photoshop Registry Version ==="
$psReg = "HKLM:\SOFTWARE\Adobe\Photoshop"
if (Test-Path $psReg) {
    Get-ChildItem $psReg -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        Write-Report "  Version: $($_.PSChildName)"
        Write-Report "    ApplicationPath: $($props.ApplicationPath)"
        Write-Report "    InstallDate: $($props.InstallDate)"
    }
} else {
    Write-Report "  [Not Found] HKLM:\SOFTWARE\Adobe\Photoshop"
}
Write-Report ""

# --- Section 3: File Extension Associations ---
foreach ($ext in $Extension) {
    Write-Report "=== 3. File Extension: $ext ==="

    # HKLM default
    $hklmKey = "HKLM:\SOFTWARE\Classes\$ext"
    if (Test-Path $hklmKey) {
        $hklmDefault = (Get-ItemProperty $hklmKey).'(default)'
        Write-Report "  HKLM Default ProgID: $hklmDefault"
    } else {
        Write-Report "  HKLM Default ProgID: [Not Found]"
    }

    # HKCU override
    $hkcuKey = "HKCU:\Software\Classes\$ext"
    if (Test-Path $hkcuKey) {
        $hkcuDefault = (Get-ItemProperty $hkcuKey -ErrorAction SilentlyContinue).'(default)'
        Write-Report "  HKCU Override ProgID: $hkcuDefault"
    } else {
        Write-Report "  HKCU Override ProgID: [None - using HKLM default]"
    }

    # HKCR merged view
    $hkcrKey = "Registry::HKEY_CLASSES_ROOT\$ext"
    if (Test-Path $hkcrKey) {
        $hkcrDefault = (Get-Item $hkcrKey).GetValue('')
        Write-Report "  HKCR Merged ProgID: $hkcrDefault (this is what Windows actually uses)"
    }

    # UserChoice
    $ucPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
    if (Test-Path $ucPath) {
        $uc = Get-ItemProperty $ucPath
        Write-Report "  UserChoice ProgId: $($uc.ProgId)"
        Write-Report "  UserChoice Hash: $($uc.Hash)"
    } else {
        Write-Report "  UserChoice: [None - system default applies]"
    }

    # OpenWithProgids
    $owpPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\OpenWithProgids"
    if (Test-Path $owpPath) {
        $owp = Get-Item $owpPath
        Write-Report "  OpenWithProgids:"
        foreach ($v in $owp.GetValueNames()) {
            Write-Report "    $v = $($owp.GetValue($v))"
        }
    }
    Write-Report ""

    # --- Section 4: ProgID Details ---
    $progIDs = @()
    if ($hklmDefault) { $progIDs += $hklmDefault }
    if ($hkcuDefault) { $progIDs += $hkcuDefault }
    if ($uc.ProgId) { $progIDs += $uc.ProgId }
    $progIDs = $progIDs | Sort-Object -Unique

    foreach ($progID in $progIDs) {
        Write-Report "=== 4. ProgID Details: $progID ==="

        # Check HKLM
        $hklmProg = "HKLM:\SOFTWARE\Classes\$progID"
        $hkcuProg = "HKCU:\Software\Classes\$progID"
        $hkcrProg = "Registry::HKEY_CLASSES_ROOT\$progID"

        $source = if (Test-Path $hkcuProg) { "HKCU" }
                  elseif (Test-Path $hklmProg) { "HKLM" }
                  else { "Not Found" }
        Write-Report "  Source: $source"

        if (Test-Path $hkcrProg) {
            $item = Get-Item $hkcrProg

            # CLSID
            $clsidPath = "$hkcrProg\CLSID"
            if (Test-Path $clsidPath) {
                $clsid = (Get-ItemProperty $clsidPath).'(default)'
                Write-Report "  CLSID: $clsid [OK]"
            } else {
                Write-Report "  CLSID: [MISSING] - ProgID is incomplete"
            }

            # DefaultIcon
            $diPath = "$hkcrProg\DefaultIcon"
            if (Test-Path $diPath) {
                $di = (Get-ItemProperty $diPath).'(default)'
                Write-Report "  DefaultIcon: $di [OK]"
            } else {
                Write-Report "  DefaultIcon: [MISSING] - No icon to display as badge"
            }

            # shell\open\command
            $cmdPath = "$hkcrProg\shell\open\command"
            if (Test-Path $cmdPath) {
                $cmd = (Get-ItemProperty $cmdPath).'(default)'
                Write-Report "  shell\open\command: $cmd [OK]"
            } else {
                Write-Report "  shell\open\command: [MISSING]"
            }

            # ShellEx
            $shellExPath = "$hkcrProg\ShellEx"
            if (Test-Path $shellExPath) {
                Write-Report "  ShellEx subkeys:"
                Get-ChildItem $shellExPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $val = (Get-ItemProperty $_.PSPath).'(default)'
                    Write-Report "    $($_.PSChildName) = $val"
                }
            } else {
                Write-Report "  ShellEx: [None]"
            }

            # Count all subkeys
            $subkeys = (Get-ChildItem $hkcrProg -ErrorAction SilentlyContinue).Count
            Write-Report "  Total subkeys: $subkeys"
        } else {
            Write-Report "  [ProgID does not exist in HKCR]"
        }
        Write-Report ""
    }

    # --- Section 5: ShellEx on extension itself ---
    Write-Report "=== 5. ShellEx on $ext ==="
    $extShellEx = "Registry::HKEY_CLASSES_ROOT\$ext\ShellEx"
    if (Test-Path $extShellEx) {
        Get-ChildItem $extShellEx -ErrorAction SilentlyContinue | ForEach-Object {
            $val = (Get-ItemProperty $_.PSPath).'(default)'
            $guid = $_.PSChildName
            $desc = switch -Wildcard ($guid) {
                "{BB2E617C-0920-11d1-9A0B-00C04FC2D6C1}" { "IExtractImage (thumbnail)" }
                "{e357fccd-a995-4576-b01f-234630154e96}" { "IThumbnailProvider" }
                "{8895b1c6-b41f-4c1c-a562-0d564250836f}" { "PreviewHandler" }
                default { "Unknown" }
            }
            Write-Report "  $guid ($desc) = $val"
        }
    } else {
        Write-Report "  [No ShellEx registered for $ext]"
    }
    Write-Report ""
}

# --- Section 6: Icaros ---
Write-Report "=== 6. Icaros Thumbnail Provider ==="
$icarosDirs = @("C:\Program Files\Icaros", "C:\Program Files (x86)\Icaros")
$icarosFound = $false
foreach ($dir in $icarosDirs) {
    if (Test-Path $dir) {
        $icarosFound = $true
        Write-Report "[Found] $dir"
        Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.exe', '.dll' } |
            ForEach-Object { Write-Report "  $($_.FullName)" }
    }
}
if (-not $icarosFound) {
    Write-Report "[Not Found] Icaros is not installed"
}

# Icaros CLSID
$icarosClsid = "HKLM:\SOFTWARE\Classes\CLSID\{c5aec3ec-e812-4677-a9a7-4fee1f9aa000}"
if (Test-Path $icarosClsid) {
    $icName = (Get-ItemProperty $icarosClsid).'(default)'
    Write-Report "  Icaros CLSID: {c5aec3ec-...} = $icName [Registered]"
    $icServer = Get-ItemProperty "$icarosClsid\InProcServer32" -ErrorAction SilentlyContinue
    if ($icServer) {
        Write-Report "  InProcServer32: $($icServer.'(default)')"
    }
} else {
    Write-Report "  Icaros CLSID: [Not registered]"
}

# Icaros registry config
$icReg = "HKLM:\SOFTWARE\Icaros"
if (Test-Path $icReg) {
    Write-Report "  Icaros registry config:"
    $icProps = Get-ItemProperty $icReg
    foreach ($p in $icProps.PSObject.Properties) {
        if ($p.Name -notmatch "^PS") {
            Write-Report "    $($p.Name) = $($p.Value)"
        }
    }
}
Write-Report ""

# --- Section 7: Thumbnail Cache Status ---
Write-Report "=== 7. Thumbnail Cache ==="
$cacheDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
$cacheFiles = Get-ChildItem $cacheDir -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
Write-Report "  Cache files: $($cacheFiles.Count)"
$totalSize = ($cacheFiles | Measure-Object Length -Sum).Sum
Write-Report "  Total size: $([math]::Round($totalSize / 1MB, 2)) MB"
Write-Report ""

# --- Section 8: Diagnosis Summary ---
Write-Report "=== 8. Diagnosis Summary ==="
foreach ($ext in $Extension) {
    Write-Report "--- $ext ---"

    $hkcrDefault = (Get-Item "Registry::HKEY_CLASSES_ROOT\$ext" -ErrorAction SilentlyContinue).GetValue('')
    $ucPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
    $ucProgId = if (Test-Path $ucPath) { (Get-ItemProperty $ucPath).ProgId } else { $null }

    $effectiveProgID = if ($ucProgId) { $ucProgId } else { $hkcrDefault }
    Write-Report "  Effective ProgID: $effectiveProgID"

    # Check ProgID completeness
    $progPath = "Registry::HKEY_CLASSES_ROOT\$effectiveProgID"
    if (Test-Path $progPath) {
        $hasCLSID = Test-Path "$progPath\CLSID"
        $hasDefaultIcon = Test-Path "$progPath\DefaultIcon"
        $hasShell = Test-Path "$progPath\shell\open\command"

        if (-not $hasCLSID) { Write-Report "  [ISSUE] ProgID missing CLSID - likely a stale shell from uninstalled software" }
        if (-not $hasDefaultIcon) { Write-Report "  [ISSUE] ProgID missing DefaultIcon - no icon resource for badge" }
        if (-not $hasShell) { Write-Report "  [ISSUE] ProgID missing shell\open\command - double-click may not work" }

        if ($hasCLSID -and $hasDefaultIcon -and $hasShell) {
            Write-Report "  [OK] ProgID is complete"
        }
    } else {
        Write-Report "  [ISSUE] ProgID does not exist - association is broken"
    }

    # Check UserChoice vs HKLM
    if ($ucProgId -and $hkcrDefault -and ($ucProgId -ne $hkcrDefault)) {
        Write-Report "  [INFO] UserChoice ($ucProgId) differs from HKLM default ($hkcrDefault)"
    }

    # Check Icaros
    $icShellEx = "Registry::HKEY_CLASSES_ROOT\$ext\ShellEx\{e357fccd-a995-4576-b01f-234630154e96}"
    if (Test-Path $icShellEx) {
        $icVal = (Get-ItemProperty $icShellEx).'(default)'
        if ($icVal -match "c5aec3ec") {
            Write-Report "  [INFO] Icaros is the thumbnail provider - badges may be masked by thumbnail preview"
        }
    }
    Write-Report ""
}

Write-Report "============================================"
Write-Report "  Report complete: $reportPath"
Write-Report "============================================"

Write-Host "Diagnostic report written to: $reportPath"
