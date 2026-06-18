---
name: windows-firewall-admin-script
description: Windows防火墙规则管理 - 管理员权限脚本创建与执行。解决 New-NetFirewallRule/netsh 无法直接执行、需要管理员权限的问题。
agent_created: true
created: 2026-05-06
updated: 2026-05-06
tags: [Windows, 防火墙, 管理员权限, PowerShell, netsh]
version: 1.0
---

# Windows 防火墙规则管理（管理员级）

## 核心经验

### 问题
WorkBuddy (CodeBuddy) 会话以普通用户身份运行，`New-NetFirewallRule` / `netsh advfirewall` 等写防火墙规则的操作全部返回 **Error 5: 拒绝访问**。

### 错误解法（已踩坑）
- ❌ 直接在 WorkBuddy PowerShell 中运行 `New-NetFirewallRule` → 权限不足
- ❌ 右键 `.bat` → "以管理员身份运行" → 调用的 PowerShell 仍是普通权限
- ❌ 右键 `.ps1` → "使用 PowerShell 运行" → 同上
- ❌ 脚本含中文 → PowerShell 默认 GB2312 读取 UTF-8 中文乱码 → 语法错误全面崩溃
- ❌ BAT 中用 `netsh advfirewall` → 含空格的路径（含括号如 `Program Files (x86)`）CMD 解析失败

### 正确解法
1. **用户手动**打开"Windows PowerShell (管理员)"（右键开始菜单）
2. 在管理员窗口中运行：`powershell -ExecutionPolicy Bypass -File "C:\Users\多福餐饮设计部\Desktop\XXX.ps1"`
3. 或右键 `Run-As-Admin.bat` → "以管理员身份运行"，BAT 内容改为：
   ```bat
   @echo off
   powershell -ExecutionPolicy Bypass -File "%~dp0XXX.ps1"
   pause
   ```

## 编码规范
- **必须使用纯 ASCII 字符**，中文全部替换为英文
- PowerShell 默认 GB2312 读取，UTF-8 中文会乱码导致解析失败
- 验证方法：`[byte[]]$b = [System.IO.File]::ReadAllBytes($file); $nonAscii = $b | Where-Object {$_ -gt 127}`

## 验证命令（WorkBuddy 可执行）
```powershell
# 检查指定规则是否存在
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*关键词*" }
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block Corel*" }

# 统计阻断规则总数
(Get-NetFirewallRule | Where-Object { $_.Action -eq "Block" }).Count
```

## 脚本模板
```powershell
# === Block-Program-Network.ps1 ===
$programs = @(
    @("Name1", "C:\Program Files\Path1\app.exe"),
    @("Name2", "C:\Program Files (x86)\Path2\app.exe")
)

foreach ($p in $programs) {
    $name = $p[0]; $path = $p[1]
    if (-not (Test-Path $path)) { Write-Host "[SKIP] $name"; continue }
    try {
        $r = "Block - $name"
        Remove-NetFirewallRule -DisplayName $r -EA SilentlyContinue
        New-NetFirewallRule -DisplayName $r -Direction Outbound -Program $path -Action Block -Enabled True -Profile Any | Out-Null
        New-NetFirewallRule -DisplayName "$r In" -Direction Inbound -Program $path -Action Block -Enabled True -Profile Any | Out-Null
        Write-Host "[OK] $name"
    } catch { Write-Host "[FAIL] $name : $_" }
}
(Get-NetFirewallRule | Where-Object {$_.DisplayName -like "Block*"}).Count
```

## 解除屏蔽
```powershell
Get-NetFirewallRule -DisplayName "Block*" | Remove-NetFirewallRule
```
