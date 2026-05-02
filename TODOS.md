# TODOS — Gmail macOS Menu Bar App

Deferred work tracked from /plan-eng-review on 2026-05-03. v1 scope is intentionally minimal.

---

## v1.1 candidates (next iteration after v1 ships)

### Quick Look 邮件预览
- **What**: 在 popover 邮件列表按空格键预览邮件正文 (NSPanel, 纯文本渲染)
- **Why**: 减少跳转浏览器频次, 提升通知中心定位的体验
- **Pros**: 用户不用为快速扫一眼邮件就跳浏览器
- **Cons**: 需 MIME parsing (multipart/alternative + base64 + charset), 复杂度高, 与"不是邮件客户端"定位有张力
- **Context**: v1 cherry-pick 接受过, 但 outside voice (Codex) 反映 MIME 复杂度被低估, 决策推迟。format=full 拉取后需要正确提取 text/plain, 处理 quoted-printable / base64 / utf-8/gbk/iso-8859-1, 多 MIME part 选择策略
- **Depends on**: v1 ship 验证通知中心定位是否成立

### .dmg + Homebrew 二进制分发
- **What**: 通过 GitHub Releases 发 .dmg, Homebrew tap (`brew tap pezy/gmail && brew install --cask gmail`)
- **Why**: 降低用户安装门槛, 真正完成"开源好用"承诺
- **Pros**: 一键安装, 自动更新可借 Sparkle 框架
- **Cons**: 与"用户必须自建 client_id"矛盾。Codex 指出: 若用户必须重建二进制, 二进制分发是 fake
- **Depends on**: Google OAuth verification 通过 (4-6 周审核), 才能内置作者 client_id 给所有用户用
- **Context**: v1 主推源码构建避免该矛盾。OAuth verification 通过后再开 binary 分发

### Google OAuth Verification
- **What**: 提交 Google 应用审核进入 Production 状态
- **Why**: Testing 状态限 100 用户 + refresh_token 7 天失效, 不适合开源分发
- **Pros**: 通过后, 用户用作者内置 client_id 即可, 无需自建 Cloud Project
- **Cons**: 需提供隐私政策 URL + 服务条款, 审核 4-6 周, 可能要求 demo 视频
- **Depends on**: 项目托管隐私政策页面 (GitHub Pages 或 README)

### GitHub Actions release.yml
- **What**: CI workflow: tag 推送 → xcodebuild archive → notarize → create-dmg → 上传 GitHub Release
- **Why**: 首次 release 手工易错 (notarization 等待时间长, 命令记不清)
- **Pros**: tag 推送即自动发版本, 流程稳定
- **Cons**: 需要 Apple Developer 凭据 secrets 配置 (App-specific password, signing cert)
- **Depends on**: .dmg 分发决策通过

### Sparkle 自动更新
- **What**: 集成 Sparkle 框架, 在应用内提示并安装新版本
- **Why**: 用户不需要每次手工 brew upgrade 或下 dmg
- **Cons**: 需要私钥签名 + appcast.xml 维护
- **Depends on**: .dmg 分发就绪

---

## v2+ candidates

### Multi-account Gmail
- **What**: 支持多 Gmail 账号切换, 菜单栏图标显示当前账号 + 切换菜单
- **Why**: 工作 + 个人邮箱场景常见
- **Cons**: AppState 重构, Keychain 多 entry 管理, 通知去重需多账号 historyId
- **Context**: v1 Keychain account 属性已用 userEmail 预留 (Decision #17)

### Label/Category 过滤
- **What**: Settings 中选择监听哪些 label / category (例: 仅 Important)
- **Why**: 重度用户 INBOX 嘈杂, 想只看重要
- **Cons**: API 调用复杂度上升 (每个 label 一次 history.list)

### 邮件搜索
- **What**: popover 顶部搜索框, 调用 messages.list(q=...) 搜索
- **Why**: 找历史邮件
- **Cons**: 搜索结果分页, UI 状态变复杂

### 菜单栏图标动画
- **What**: 新邮件到达时菜单栏 SF Symbol 短暂动画 (envelope → envelope.fill 闪烁)
- **Why**: 视觉提示, 用户更容易注意到新邮件
- **Cons**: NSStatusItem 自定义动画支持差, 需 NSImage 序列帧切换

---

## 不计划做

### Mac App Store 分发
- **Why not**: 全局快捷键 (NSEvent.addGlobalMonitorForEvents) 在 Sandbox 下不可用, 需重写为 Carbon RegisterEventHotKey + Accessibility permission, 工作量大且 App Store 审核倾向严格
- **如果重要**: 重新评估全局快捷键的价值, 或为 App Store 版本去掉该功能

### 发送/回复邮件
- **Why not**: 与"不是邮件客户端, 是通知中心"定位冲突。点击邮件跳浏览器写已经够了
- **替代方案**: 配合 Apple Mail / Mimestream 使用
