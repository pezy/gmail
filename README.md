# Gmail — macOS 菜单栏 Gmail 通知

> **🚧 v1.0.0-beta** — 仅源码构建。需要自建 Google Cloud OAuth 凭据。`.dmg` 二进制分发待 OAuth verification 通过后开放。

一个住在菜单栏的极简 Gmail 通知应用。新邮件来了你知道，想看就看，想回复跳到网页版。Swift + SwiftUI 原生开发。

## 特性 (v1)

- 菜单栏图标 + 未读邮件计数 (✉ N)
- 新邮件到达 → macOS 原生通知 (含发件人 + 主题)
- 点击通知 / 邮件行 → 默认浏览器打开 Gmail 网页版的对应邮件
- popover 显示最近 20 条未读邮件 (380×480pt)
- 增量轮询 (history.list), 稳态 ~1-3 quota units/poll
- 错误状态视觉反馈 (auth ⚠️ 黄 / 网络断开 灰 / API 错误 ⚠️ 红, 优先级递减)
- 全局快捷键唤出 popover (Settings 中可配置, 默认不绑定避免冲突)
- 开机自启 (SMAppService, Settings 中可开关)
- 4 种空态 (未登录 / 需重新授权 / Inbox Zero / 错误)

## 系统要求

- macOS 14 (Sonoma) 或更新
- Xcode 15+ / Swift 6.0+ (`xcode-select --install` 即可)

## 构建

### 1. 创建 Google Cloud OAuth 凭据

1. 访问 [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. 选择 / 创建一个 Google Cloud Project
3. 启用 Gmail API: APIs & Services → Library → Gmail API → Enable
4. OAuth consent screen → 配置基本信息 → User Type 选 External, Publishing status 暂时为 "Testing"
5. Credentials → Create Credentials → OAuth client ID → Application type = **Desktop app**
6. 复制 Client ID, 形如 `123456789-abcdef.apps.googleusercontent.com`

> **⚠️ Testing 状态限制**
> Google OAuth Testing 状态下:
> - 仅添加到 OAuth consent screen "Test users" 的 Google 账号可登录
> - refresh_token 7 天后失效, 用户需重新授权
>
> 这是 Google 的限制不是本应用 bug。可通过 OAuth verification 进入 Production 状态消除限制 (审核约 4-6 周)。

### 2. 构建 .app

```bash
git clone https://github.com/pezy/gmail.git
cd gmail
OAUTH_CLIENT_ID="123456789-abcdef.apps.googleusercontent.com" ./scripts/build.sh
```

构建输出: `./Gmail.app`

### 3. 运行

```bash
open Gmail.app
```

首次运行 macOS Gatekeeper 会拦截 (二进制未签名)。两种处理方式:
- 在 Finder 中右键 → Open, 在弹窗中点 Open 一次即可
- 或命令行: `xattr -d com.apple.quarantine Gmail.app && open Gmail.app`

应用启动后菜单栏出现 ✉ 图标。点击 → 弹出 popover → "Connect Gmail" 触发 Google 授权窗口。

## 测试

```bash
swift test
```

包含 67+ 单元测试覆盖 OAuth 状态机、Keychain、Gmail API 解析、轮询状态机、通知去重、UI presenter 等。

## 设计文档

完整设计文档与决策记录在 `~/.gstack/projects/pezy-gmail/ceo-plans/20260503-gmail-menubar.md`。

## 许可

MIT
