# Windows File Association Registry Guide

This reference explains the Windows registry structure that controls file type
icons, badges, and thumbnail previews. Understanding this structure is essential
for diagnosing missing Adobe software badges.

## HKCR: The Merged View

`HKEY_CLASSES_ROOT` (HKCR) is a **merged view** of two locations:

| Source | Path | Priority | Admin Required |
|--------|------|----------|----------------|
| User-specific | `HKCU\Software\Classes\` | **Higher** | No |
| System-wide | `HKLM\SOFTWARE\Classes\` | Lower | Yes |

When both locations define the same key, **HKCU wins**. This means you can
override system-wide file associations without admin privileges by writing to
HKCU.

## Registry Structure for a File Extension

Here is the complete structure for `.psd` as an example:

```
HKCR\.psd                          (default) = "Photoshop.Image.24"    ← ProgID pointer
  ├── OpenWithProgids              Photoshop.Image.24 = 0x00000000    ← Additional ProgIDs
  ├── PersistentHandler            (default) = "{...}"               ← For desktop search
  └── ShellEx
      ├── {BB2E617C-...}           (default) = "{Icaros-CLSID}"      ← IExtractImage (thumbnail)
      ├── {e357fccd-...}           (default) = "{Icaros-CLSID}"      ← IThumbnailProvider
      └── {8895b1c6-...}           (default) = "{PreviewHandler}"    ← Preview pane handler

HKCR\Photoshop.Image.24            (default) = "Adobe Photoshop File" ← ProgID definition
  ├── CLSID                        (default) = "{2c07c258-...}"       ← COM class for OLE
  ├── DefaultIcon                  (default) = "C:\...\Photoshop.exe,1" ← Icon resource for badge
  ├── shell
  │   └── open
  │       └── command              (default) = "C:\...\Photoshop.exe" "%1" ← Double-click action
  └── ShellEx                      (optional)
```

## Key Components Explained

### ProgID (Programmatic Identifier)

A ProgID like `Photoshop.Image.24` is a named reference to a file type
association. The version number suffix (`.24`, `.27`) corresponds to the
Photoshop major version:

- `.24` = Photoshop 2023 (version 24.x)
- `.25` = Photoshop 2024 (version 25.x)
- `.26` = Photoshop 2025 (version 26.x)
- `.27` = Photoshop 2026 (version 27.x)

When Photoshop is uninstalled, it may leave the ProgID shell in the registry
but remove the CLSID and other critical subkeys, creating an "empty shell"
ProgID.

### DefaultIcon

The `DefaultIcon` subkey of a ProgID specifies the icon resource used for the
file type. The value format is:

```
<icon-source-path>,<index>
```

- `C:\Program Files\Adobe\Adobe Photoshop 2023\Photoshop.exe,1` — Extract the
  second icon group (0-indexed) from the exe
- `C:\Program Files\Adobe\Adobe Photoshop 2023\Photoshop.exe,0` — First icon
- `C:\Windows\System32\shell32.dll,42` — System icon by index

**This is the key that Windows uses to render the software badge overlay.**
If DefaultIcon is missing, no badge appears.

### UserChoice

Located at:
```
HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.psd\UserChoice
```

This key stores the user's file association choice (e.g., when a user picks
"Open with → Photoshop"). It contains:

| Value | Description |
|-------|-------------|
| `ProgId` | The ProgID the user chose (e.g., `Photoshop.Image.27`) |
| `Hash` | A signature that validates the ProgId (Windows 10/11 protection) |

**UserChoice overrides the HKLM default.** If UserChoice points to a stale
ProgID, the badge won't appear even if HKLM has the correct default.

**Hash protection**: On Windows 10/11, you cannot simply change the ProgId
value — the hash won't match and Windows will ignore it. The key must be
**deleted entirely** so the system regenerates it.

### ShellEx (Shell Extensions)

ShellEx subkeys register COM objects that extend Windows Shell behavior for a
file type:

| GUID | Interface | Purpose |
|------|-----------|---------|
| `{BB2E617C-0920-11d1-9A0B-00C04FC2D6C1}` | IExtractImage | Legacy thumbnail extraction |
| `{e357fccd-a995-4576-b01f-234630154e96}` | IThumbnailProvider | Modern thumbnail provider |
| `{8895b1c6-b41f-4c1c-a562-0d564250836f}` | IPreviewHandler | Preview pane handler |

ShellEx can be registered at two levels:
1. **On the extension** (`HKCR\.psd\ShellEx\...`) — applies to all ProgIDs
2. **On the ProgID** (`HKCR\Photoshop.Image.24\ShellEx\...`) — ProgID-specific

### Icaros Thumbnail Provider

Icaros is a third-party thumbnail provider that supports many media formats.
When registered for `.psd`, it generates image previews of the PSD content.

- **Icaros CLSID**: `{c5aec3ec-e812-4677-a9a7-4fee1f9aa000}`
- **DLL**: Typically `IcarosThumbnailProvider.dll` in `C:\Program Files\Icaros\`

Icaros generates **thumbnails** (content previews) but does **not** add the
Adobe software badge overlay. When Icaros is active for `.psd`, the badge is
typically hidden behind the thumbnail.

Compare with `.ai` files: Illustrator registers its own `AIPreviewHandler.dll`
which provides both thumbnail AND badge, so `.ai` files show the Ai badge even
with Icaros installed.

## Comparison: Working .ai vs Broken .psd

### .ai (working — has badge)
```
HKCR\.ai
  (default) = "Illustrator.Artwork"
  ShellEx
    {BB2E617C-...} = {c5aec3ec-...} (Icaros)
    {8895b1c6-...} = {DDB16B7D-...} (AIPreviewHandler) ← This provides the badge

HKCR\Adobe.Illustrator.30
  CLSID = {C3D06A66-...}                              ← Complete
  DefaultIcon = "C:\...\Illustrator.exe,1"             ← Icon resource
  shell\open\command = "C:\...\Illustrator.exe" "%1"   ← Open action
  (18 subkeys total)                                   ← Fully registered
```

### .psd (broken — no badge)
```
HKCR\.psd
  (default) = "Photoshop.Image.27"         ← Stale! PS 2026 uninstalled
  ShellEx
    {BB2E617C-...} = {c5aec3ec-...} (Icaros)
    {e357fccd-...} = {c5aec3ec-...} (Icaros)
    (no PreviewHandler)                     ← Missing! No badge source

HKCR\Photoshop.Image.27
  DefaultIcon = "C:\...\Photoshop.exe,1"   ← Added manually
  shell\open\command = "..."               ← Added manually
  (no CLSID)                               ← INCOMPLETE: empty shell
  (only 2 subkeys)                         ← Should have 10+

HKCR\Photoshop.Image.24                    ← The correct one (PS 2023)
  CLSID = {2c07c258-...}                   ← Complete
  DefaultIcon = "C:\...\Photoshop.exe,1"   ← Has icon
  shell\open\command = "..."               ← Has open action
  (10+ subkeys)                            ← Fully registered
```

## Thumbnail vs Badge Tradeoff

| Feature | Icaros Thumbnail | Windows DefaultIcon |
|---------|-----------------|---------------------|
| Shows file content preview | Yes | No |
| Shows software badge (Ps/Ai) | No | Yes |
| Requires third-party software | Yes (Icaros) | No (built-in) |
| Performance | Slightly slower (renders content) | Instant (reads cached icon) |

Users must choose between thumbnail preview and badge, or use a tool that
provides both (like Adobe's own thumbnail provider, if available for their
version).
