# windows-firewall-admin-script

Windows 防火墙规则管理技能 —— 解决 WorkBuddy 普通权限环境下无法执行防火墙管理命令的问题。

## 快速安装

将本目录复制到：
```
C:\Users\<用户名>\.workbuddy\skills\windows-firewall-admin-script\
```

重启 WorkBuddy 后即可使用。

## 核心解决的问题

- `New-NetFirewallRule` 返回 Error 5（拒绝访问）
- PowerShell 脚本中文乱码导致执行失败
- BAT 脚本调用 PowerShell 权限提升方案

## 版本

v1.0 | 创建: 2026-05-06
