# WorkBuddy Skills — xingyue6202

> 这是 Jay（[@xingyue6202](https://github.com/xingyue6202)）在使用 [WorkBuddy](https://www.codebuddy.cn) 过程中积累并自制的 Skills 集合。
> 每个 Skill 均由 AI 代为创建，记录了真实踩坑经验与可复用的工作流。

---

## 📦 Skills 列表

| Skill 目录 | 版本 | 描述 |
|---|---|---|
| [adobe-troubleshooter](./skills/adobe-troubleshooter/) | v1.3.0 | Adobe CC 系列软件问题排查（弹窗、激活、功能故障） |
| [windows-firewall-admin-script](./skills/windows-firewall-admin-script/) | v1.0 | Windows 防火墙规则管理（管理员权限脚本方案） |

---

## 🚀 如何在 WorkBuddy 中使用

### 方法一：直接下载安装（推荐）

1. 下载对应 Skill 目录下的 `SKILL.md`
2. 将整个目录（如 `adobe-troubleshooter/`）放到：
   ```
   C:\Users\<你的用户名>\.workbuddy\skills\adobe-troubleshooter\
   ```
3. 重启 WorkBuddy，在对话中直接呼叫 Skill 名称即可

### 方法二：Git Clone 后软链接

```bash
git clone https://github.com/xingyue6202/workbuddy-skills.git
# 然后将 skills/ 下的目录复制或软链接到 ~/.workbuddy/skills/
```

### 方法三：直接引用原始内容

在 WorkBuddy 对话中说：
> "加载这个 skill：https://raw.githubusercontent.com/xingyue6202/workbuddy-skills/main/skills/adobe-troubleshooter/SKILL.md"

---

## 📁 目录结构

```
workbuddy-skills/
├── README.md                          ← 本文件
└── skills/
    ├── adobe-troubleshooter/
    │   └── SKILL.md                   ← Adobe 问题排查
    └── windows-firewall-admin-script/
        └── SKILL.md                   ← Windows 防火墙管理员脚本
```

---

## 🔧 Skills 说明

### adobe-troubleshooter

**用途**：解决 Adobe Photoshop、Illustrator、Premiere Pro、After Effects 等 CC 系列软件的常见使用问题。

**涵盖场景**：
- 非正版弹窗处理（"Your non-genuine Adobe app will be disabled soon"）
- AdobeGCClient 权限修改
- hosts 文件屏蔽验证服务器
- 功能异常修复

**适用人群**：设计师、视频编辑、创意工作者。

---

### windows-firewall-admin-script

**用途**：解决在 WorkBuddy（CodeBuddy）普通用户权限环境下无法执行 Windows 防火墙规则管理命令的问题。

**核心经验**：
- `New-NetFirewallRule` / `netsh advfirewall` 需要管理员权限
- 含中文的 PowerShell 脚本在默认 GB2312 编码下会乱码崩溃
- 提供了正确的管理员脚本执行方法和纯 ASCII 编码规范

**适用场景**：批量屏蔽软件联网、网络安全配置、防火墙规则管理。

---

## 📅 更新记录

| 日期 | 变更 |
|---|---|
| 2026-06-18 | 初始提交，包含 2 个自制 Skills |

---

## 📬 联系

- GitHub: [@xingyue6202](https://github.com/xingyue6202)
- 工作环境: 多福餐饮（朴大叔拌饭）品牌运营中心
