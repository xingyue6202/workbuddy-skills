---
name: windows-adobe-badge-fix
description: "Fix missing Adobe software badges (Ps/Ai icons) on .psd/.ai files in Windows Explorer. Covers diagnosing broken ProgID registrations after Photoshop uninstall/reinstall, Icaros thumbnail provider conflicts, missing DefaultIcon entries, and UserChoice pointing to stale ProgIDs. Use this skill when .psd or .ai files lack the software badge overlay in Windows Explorer, or after uninstalling/reinstalling Adobe products that break file associations."
agent_created: true
---

# Windows Adobe Badge Fix

## Overview

Fix missing Adobe software badges (e.g. "Ps" for Photoshop, "Ai" for Illustrator)
on `.psd` / `.ai` files in Windows Explorer. The badge is a small overlay icon
rendered by Windows Shell when a file type has a properly registered ProgID with
a `DefaultIcon` entry pointing to the application's icon resource.

Common causes of missing badges:
1. **Stale ProgID** — Photoshop was uninstalled/reinstalled, leaving an old
   `Photoshop.Image.27` (PS 2026) shell while the current install registers
   `Photoshop.Image.24` (PS 2023). The `.psd` extension still points to the old,
   now-empty ProgID.
2. **Missing DefaultIcon** — The ProgID has no `DefaultIcon` subkey, so Windows
   cannot find an icon resource to overlay.
3. **Icaros override** — The Icaros thumbnail provider generates raw thumbnails
   for `.psd` without adding the Adobe badge, masking the underlying icon.
4. **UserChoice lock-in** — `HKCU\...\FileExts\.psd\UserChoice` points to a
   broken ProgID and overrides HKLM defaults.

## Diagnosis Workflow

### Step 1: Run the Diagnostic Script

Execute the bundled diagnostic script to collect all relevant registry state in
one pass:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts/diagnose_adobe_badge.ps1
```

The script writes results to `%TEMP%\adobe_badge_report.txt`. Read that file to
review the findings.

### Step 2: Identify the Root Cause

Cross-reference the diagnostic report against this table:

| Symptom in Report | Root Cause | Fix Section |
|---|---|---|
| `.psd` default ProgID differs from installed PS version's ProgID | Stale ProgID | [Fix A](#fix-a-override-stale-progid) |
| ProgID has no `DefaultIcon` subkey | Missing DefaultIcon | [Fix B](#fix-b-register-defaulticon) |
| ProgID has no `CLSID` subkey | Incomplete / empty shell ProgID | [Fix A](#fix-a-override-stale-progid) |
| `UserChoice` ProgId differs from HKLM default | UserChoice lock-in | [Fix C](#fix-c-clear-stale-userchoice) |
| Icaros registered as ThumbnailProvider for `.psd` | Icaros masking badge | [Fix D](#fix-d-icaros-configuration) |

Multiple causes can coexist — address them in order A → B → C → D.

### Step 3: Determine the Correct ProgID

Find which `Photoshop.Image.NN` ProgID is complete (has CLSID + DefaultIcon +
shell). The version number corresponds to the PS release:

| ProgID | Photoshop Version |
|---|---|
| `Photoshop.Image.24` | Photoshop 2023 |
| `Photoshop.Image.25` | Photoshop 2024 |
| `Photoshop.Image.26` | Photoshop 2025 |
| `Photoshop.Image.27` | Photoshop 2026 |

Check the installed Photoshop version:
```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Adobe\Photoshop\*" -ErrorAction SilentlyContinue |
  Select-Object PSChildName, ApplicationPath
```

## Fix Procedures

### Fix A: Override Stale ProgID

When `.psd` points to a broken ProgID (e.g. `.27` from uninstalled PS 2026),
override it in HKCU to point to the complete ProgID from the currently
installed PS version:

```powershell
# Replace .24 with the correct version for the installed Photoshop
$key = "HKCU:\Software\Classes\.psd"
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name "(default)" -Value "Photoshop.Image.24" -Type String
```

HKCU overrides HKLM in the merged HKCR view, so this takes effect without admin
privileges.

### Fix B: Register DefaultIcon

If the ProgID lacks a `DefaultIcon` entry, register one pointing to the
Photoshop executable:

```powershell
# Find the Photoshop.exe path
$psExe = Get-ChildItem "C:\Program Files\Adobe\Adobe Photoshop *\Photoshop.exe" |
  Select-Object -First 1 -ExpandProperty FullName

# Register DefaultIcon in HKCU (no admin needed)
$key = "HKCU:\Software\Classes\Photoshop.Image.24\DefaultIcon"
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name "(default)" -Value "$psExe,1"

# Also register shell open command if missing
$key2 = "HKCU:\Software\Classes\Photoshop.Image.24\shell\open\command"
New-Item -Path $key2 -Force | Out-Null
Set-ItemProperty -Path $key2 -Name "(default)" -Value "`"$psExe`" `"%1`""
```

The icon index `,1` extracts the second icon group from the exe. If the badge
still doesn't appear, try `,0`.

### Fix C: Clear Stale UserChoice

Windows stores user-chosen file associations in `UserChoice`. This key has a
hash-protected ProgId that overrides HKLM defaults. Delete it to let the system
fall back to HKLM:

```powershell
$uc = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.psd\UserChoice"
if (Test-Path $uc) { Remove-Item -Path $uc -Force }

$owp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.psd\OpenWithProgids"
if (Test-Path $owp) { Remove-Item -Path $owp -Force }
```

After deleting UserChoice, the `.psd` association reverts to the HKLM default
(or the HKCU override from Fix A if applied).

### Fix D: Icaros Configuration

If Icaros is the thumbnail provider for `.psd`, it generates raw image
thumbnails without the Adobe badge overlay. Options:

1. **Exclude .psd from Icaros**: Open `C:\Program Files\Icaros\IcarosConfig.exe`,
   find `.psd` in the extension list, uncheck it, click Apply. Windows will fall
   back to the DefaultIcon for `.psd` files (showing the Ps badge but losing
   thumbnail preview).

2. **Keep Icaros for thumbnails, accept no badge**: This is the default state.
   Thumbnails are more useful than badges for most users.

3. **Do NOT blindly disable Icaros ShellEx**: Setting the Icaros CLSID to empty
   in `HKCU\...\ShellEx` will remove BOTH the thumbnail AND the badge. Only do
   this if you explicitly want plain file icons.

## Post-Fix: Clear Cache and Restart Explorer

After any registry change, clear the thumbnail cache and restart Explorer:

```powershell
# Stop Explorer
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 2

# Delete thumbnail cache files
$cacheDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
Get-ChildItem -Path $cacheDir -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue |
  ForEach-Object { [System.IO.File]::Delete($_.FullName) }

# Delete icon cache
$iconCache = "$env:LOCALAPPDATA\IconCache.db"
if (Test-Path $iconCache) { [System.IO.File]::Delete($iconCache) }

# Notify system of association change
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Shell32Notify {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@ -ErrorAction SilentlyContinue
[Shell32Notify]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)

# Restart Explorer
Start-Process explorer.exe
```

## Key Pitfalls

1. **HKLM requires admin** — Writing to `HKLM:\SOFTWARE\Classes\...` requires
   elevated privileges. Prefer HKCU overrides which work without admin and take
   precedence in the merged HKCR view.

2. **PowerShell tool output issues** — In some sandboxed environments, direct
   PowerShell output may not be captured. Write results to a temp file and read
   it back with a separate command.

3. **Multiple Photoshop versions** — After uninstalling PS 2026 and installing
   PS 2023, the HKLM `.psd` default may still point to `Photoshop.Image.27`
   (the 2026 shell). The `.24` shell from 2023 exists but is not the default.
   Must override in HKCU or fix HKLM with admin.

4. **Icaros caches thumbnails** — Even after registry fixes, Icaros may serve
   cached thumbnails. Delete `IcarosCache\Icaros_idx.icdb` (in Program Files or
   VirtualStore) and clear the Windows thumbnail cache.

5. **UserChoice hash protection** — Windows 10/11 protects UserChoice with a
   hash. Simply changing the ProgId value will not work; the key must be deleted
   entirely so the system regenerates it.

6. **Thumbnail vs Badge tradeoff** — Icaros generates image thumbnails (useful
   for previewing PSD content) but does not add the Ps badge. Windows native
   DefaultIcon shows the Ps badge but no thumbnail preview. Choose based on
   user preference.

## Resources

### scripts/
- `diagnose_adobe_badge.ps1` — PowerShell diagnostic script that checks all
  relevant registry keys for `.psd` and `.ai` file associations, Icaros
  configuration, and installed Adobe products. Outputs a report to
  `%TEMP%\adobe_badge_report.txt`.

### references/
- `registry_guide.md` — Detailed reference on Windows file association registry
  structure (HKCR merge view, ProgID, UserChoice, ShellEx, DefaultIcon) with
  annotated examples from real `.psd` and `.ai` registrations.
