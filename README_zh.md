<h4 align="right"><a href="README.md">English</a> | <strong>简体中文</strong></h4>

<p align="center">
  <img src="https://img.shields.io/badge/-Gmail-EA4335?logo=gmail&logoColor=white&style=for-the-badge" width="138" />
  <h1 align="center">Gmail</h1>
  <div align="center">
    <a href="https://github.com/pezy/gmail/releases" target="_blank">
      <img alt="状态" src="https://img.shields.io/badge/status-beta-orange?style=flat-square"></a>
    <a href="LICENSE" target="_blank">
      <img alt="许可证" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"></a>
    <img alt="Swift 6.0+" src="https://img.shields.io/badge/Swift-6.0%2B-F05138?style=flat-square&logo=swift&logoColor=white">
    <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-orange?style=flat-square">
  </div>
  <div align="center">macOS 上的极简 Gmail 菜单栏应用。原生通知，仅此而已。</div>
</p>

## 为什么做这个

macOS 上没有好用的开源 Gmail 客户端。网页版没有原生通知，没有 Dock badge。Mimestream 闭源收费。Apple Mail 用起来不像 Gmail。Electron 系太重。

这个 app 只做一件事：新邮件来了告诉你。点通知跳浏览器打开。够了。

## 特性

- **菜单栏常驻** — `LSUIElement=true`, 无 Dock 图标, 无主窗口
- **原生通知** — UNUserNotificationCenter, 点击直接跳浏览器
- **增量轮询** — `users.history.list` 让稳态成本压在 ~1-3 quota units/次
- **状态优先级图标** — auth ⚠️ 黄 / 网络断开 灰 / API ⚠️ 红 / 正常 黑
- **四种空态** — 未登录 / 需重新授权 / Inbox Zero / 错误 + 重试
- **可配置轮询间隔** — 默认 60s, Settings 中可调 120s / 5min / 10min
- **开机自启** — SMAppService 一键开关
- **多账号安全 URL** — 通知点击打开正确的 Inbox, 不会跳到错的浏览器账号

## 系统要求

- macOS 14 (Sonoma) 或更高
- Xcode 15+ (`xcode-select --install`)
- 一个 Google Cloud OAuth 2.0 Client ID (Desktop app 类型)

## 安装

> ⚠️ **v1.0.0-beta** — 仅源码构建. 等 Google OAuth verification 通过后会开放 `.dmg` + Homebrew cask 分发。

### 1. 创建 Google Cloud OAuth 凭据

1. 打开 [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. 选择已有 Project 或新建一个
3. 启用 Gmail API: **APIs & Services → Library → Gmail API → Enable**
4. 配置 OAuth consent screen (User Type = External, Publishing status = Testing)
5. **Create Credentials → OAuth client ID → Application type = Desktop app**
6. 复制 **Client ID** (`123-abc.apps.googleusercontent.com`) 和 **Client Secret** (`GOCSPX-...`)

> **Testing 状态限制** (Google 规则, 非应用 bug):
>
> - 只有添加到 consent screen *Test users* 列表的 Google 账号可以登录
> - refresh_token 7 天后失效, 应用会提示重新授权
>
> 提交 OAuth verification (需隐私政策 URL, 审核约 4 周) 可消除限制。

### 2. 构建

```bash
git clone https://github.com/pezy/gmail.git
cd gmail
OAUTH_CLIENT_ID="123-abc.apps.googleusercontent.com" \
OAUTH_CLIENT_SECRET="GOCSPX-..." \
./scripts/build.sh
```

脚本会把 `Gmail.app` 写入仓库根目录。

### 3. 运行

```bash
xattr -d com.apple.quarantine Gmail.app  # 移除未签名二进制的 Gatekeeper 隔离
open Gmail.app
```

菜单栏出现 ✉。点击 → **Connect Gmail** → 在 Safari 完成 OAuth → 几秒内邮件列表出现。

## 用法

- **点菜单栏 ✉** 唤出/收起 popover
- **点击邮件行** → 默认浏览器打开
- **popover footer 的 ⚙** → Settings
- **footer 的退出图标** → 清空 token 并重置状态. 任何卡死状态都能用它清

## 测试

```bash
swift test
```

67 个单元测试: OAuth 状态机 / Keychain 读写 / Gmail API 解析 / 轮询状态机 / 通知去重 / 菜单栏 presenter / Settings 持久化。

## 后续路线

参见 [TODOS.md](TODOS.md), 包含:

- 多账号支持
- Quick Look 邮件预览 (空格键)
- `.dmg` 分发 + Homebrew cask
- Sparkle 自动更新
- Mac App Store 分发

## 技术栈

- **语言**: Swift 6 (strict concurrency)
- **UI**: SwiftUI + AppKit (`NSStatusItem`, `NSPopover`, `NSPanel`, `NSWindow`)
- **OAuth**: [AppAuth-iOS](https://github.com/openid/AppAuth-iOS) (唯一第三方依赖)
- **网络**: `URLSession`
- **通知**: `UNUserNotificationCenter`
- **Token 存储**: Security framework (Keychain), `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- **开机自启**: `SMAppService`
- **轮询**: `NSBackgroundActivityScheduler`
- **网络监控**: `NWPathMonitor`

## 架构

10 个聚焦模块, 共享一个 `@MainActor @Observable AppState`:

```
AuthService -- AppAuthAuthorizer -- KeychainService
GmailAPIClient -- HTTPS to gmail.googleapis.com
PollingCoordinator (状态机) -- NetworkMonitor
NotificationManager (UNUserNotificationCenter)
StatusBarController + PopoverView + SettingsView (UI)
LoginItemsManager (SMAppService)
```

完整架构图与决策记录见 [设计文档](https://github.com/pezy/gmail/blob/main/CLAUDE.md)。

## 致谢

- [AppAuth-iOS](https://github.com/openid/AppAuth-iOS) by Google, OAuth 处理交给它就不用自己踩坑了
- [MiaoYan](https://github.com/tw93/MiaoYan), README 格式参考

## 许可证

[MIT](LICENSE)
