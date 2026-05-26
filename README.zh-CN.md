# OTPilot

中文 | [English](README.md)

OTPilot 是一个 macOS 13+ 菜单栏小工具，用来处理短信一次性验证码。它会读取本机 Messages 数据库，从新收到的 SMS / iMessage 记录里提取可能的验证码，复制到剪贴板，并且可以选择自动粘贴到当前聚焦的输入框。

它主要是为 Dia、Chrome、Arc 这类浏览器准备的：当 macOS 没有提供 Safari 那种短信验证码自动填充体验时，OTPilot 用「剪贴板 + 粘贴」提供一个轻量替代方案。

## 功能

- 菜单栏应用，不显示 Dock 图标。
- 读取 `~/Library/Messages/chat.db` 里的新 SMS / iMessage 记录。
- 支持常见英文和中文验证码短信格式。
- 检测到验证码后自动复制到剪贴板。
- 可选自动粘贴，也就是发送 Command-V。
- 可选在 45 秒后恢复原剪贴板内容。
- 当验证码只被复制、仍需手动粘贴时，显示通知反馈。
- 可选开机登录时启动。
- 默认在应用打开后自动开始监听。

## 系统要求

OTPilot 目前还没有提供经过 notarization 的预构建版本。现在建议从源码构建。

- macOS 13 或更新版本。
- Mac 上已经配置 Messages，并开启短信转发或 iMessage 同步。
- 给 OTPilot 授予 Full Disk Access 权限。
- 如果启用 `Auto paste`，还需要授予 Accessibility 权限。
- macOS 13 SDK 或更新版本。
- Xcode 或 Apple Command Line Tools，并且本机有 `swift`、`make`、`codesign` 和常规 macOS 开发工具。
- 可选但推荐：本机 Keychain 里有一张 Apple Development 签名证书。免费 Apple ID 的开发证书就足够本地使用；只有做更正式的公开分发和 notarization 时，才需要 Developer ID 证书。

你可以这样检查本机工具链：

```bash
swift --version
security find-identity -v -p codesigning
```

## 安装与运行

### 给不熟悉命令行的用户

OTPilot 目前以源码形式分发，还不是一个经过 notarization 的 `.app` 安装包。

1. 打开 [v1.2 release](https://github.com/Cococolins/OTPilot/releases/tag/v1.2)。
2. 下载 `OTPilot-v1.2-source.zip`。
3. 解压这个文件。
4. 打开解压后的 `OTPilot-v1.2` 文件夹。
5. 双击 `Install OTPilot.command`。

如果 macOS 提示脚本无法打开，可以右键点击 `Install OTPilot.command`，选择 `Open`，再确认打开。这个安装脚本会自动打开 Terminal，构建 OTPilot，复制到 `/Applications/OTPilot.app`，然后启动应用。

如果安装脚本提示找不到 Swift 或 `make`，需要先安装 Apple Command Line Tools。按 Command-Space 打开 Spotlight，输入「终端」或 `Terminal`，打开 Terminal app，把下面这行命令复制进去，然后按 Return：

```bash
xcode-select --install
```

macOS 会弹出安装提示，按提示安装完成后，再双击一次 `Install OTPilot.command`。

### 给熟悉 Terminal 的用户

安装命令需要在项目文件夹里运行。比如用 Git clone：

```bash
git clone https://github.com/Cococolins/OTPilot.git
cd OTPilot
make install
```

如果你下载的是源码 ZIP，先解压，打开 Terminal，`cd` 到解压后的 `OTPilot` 文件夹，再运行：

```bash
make install
```

这个命令会构建 SwiftPM 应用，在 `dist/OTPilot.app` 里组装 app bundle，签名，复制到 `/Applications/OTPilot.app`，然后启动安装后的应用。

你也可以直接调用底层脚本：

```bash
./script/build_and_run.sh --install
```

开发时也建议一直使用 `--install`。macOS 的隐私权限和 app 身份、路径有关；如果你在 `dist/OTPilot.app` 和 `/Applications/OTPilot.app` 之间来回切换，可能会看到系统设置里权限似乎已经打开，但实际运行中的 app 仍然不被信任。

## 权限

OTPilot 需要 Full Disk Access 来读取：

```text
~/Library/Messages/chat.db
```

自动粘贴需要 Accessibility 权限。OTPilot 会用 Accessibility API 检查当前聚焦的 UI 元素是不是可编辑文本框；如果是，就发送 Command-V，让浏览器里的 paste 事件继续生效，包括 6 个独立小格的 OTP 输入框。如果没有可编辑文本框处于焦点中，OTPilot 会保留剪贴板里的验证码并发通知，而不是盲目发送 Command-V。

如果自动粘贴不工作，可以检查日志：

```bash
log show --last 5m --predicate 'subsystem == "app.otpilot.OTPilot"' --style compact
```

正常自动粘贴时，你应该能看到类似日志：

```text
Detected OTP ... autoPaste=true; accessibilityTrusted=true
Posted Command-V event
```

`Posted Command-V event` 代表 OTPilot 已经确认有可编辑文本框处于焦点中，并发送了键盘事件。macOS 仍然不会告诉 OTPilot 目标 app 是否真的接收并插入了内容。

如果日志里出现 `Accessibility is not trusted`，可以在系统设置里移除旧的 OTPilot 权限记录，重新添加 `/Applications/OTPilot.app`，然后打开权限。

通知不会显示验证码本身，也不会显示发件人。OTPilot 只会在「验证码已复制、但没有找到可编辑焦点」时发通知；如果它已经向聚焦文本框发送 Command-V，就不会再发通知，因为粘贴动作本身已经是反馈。

## 签名

构建脚本会优先使用本机 Keychain 里的 `Apple Development` 签名证书；如果没有找到，就退回到 ad-hoc 签名。

稳定签名有助于 macOS 在应用更新后继续保留 Full Disk Access、Accessibility 和 Login Items 权限。

ad-hoc 签名的本地构建也可以运行，但 macOS 可能会把频繁重建后的 app 当成新身份。如果你发现每次构建后权限都像被重置了一样，建议使用稳定的 Apple Development 证书，并且始终安装到 `/Applications/OTPilot.app`。

如果要公开发布 GitHub Release，Developer ID 签名和 notarization 会带来最顺滑的首次打开体验。没有 notarization 时，用户第一次打开可能需要右键选择 Open，或在 Privacy & Security 里手动批准。

手动指定签名身份：

```bash
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./script/build_and_run.sh --install
```

手动指定 bundle identifier：

```bash
BUNDLE_ID="com.example.OTPilot" ./script/build_and_run.sh --install
```

## 验证码解析

解析器同时针对英文和中文短信模板做了优化，不假设验证码一定出现在关键词后面。

支持的例子包括：

```text
【豆瓣网】豆瓣登录验证码：2463
【哔哩哔哩】597700短信登录验证码
[瑞幸咖啡] 验证码：088864
Use 837201 as your login code.
G-789012 is your Google verification code
```

当前策略大致是：

1. 查找验证码相关关键词，包括简体和繁体中文变体。
2. 枚举关键词附近 4-8 位的候选字符串。
3. 过滤掉像日期、时间、URL 的 token。
4. 优先排序 6 位数字验证码，其次是 4 位数字、其他数字和字母数字混合验证码。

## 常用命令

只构建：

```bash
make build
```

安装并启动：

```bash
make install
```

验证进程是否启动：

```bash
make verify
```

查看应用日志：

```bash
make telemetry
```

检查当前运行路径：

```bash
ps -axo pid,comm,args | rg 'OTPilot' | rg -v rg
```

检查签名：

```bash
codesign -dv --verbose=4 /Applications/OTPilot.app 2>&1 | sed -n '1,90p'
```

## 参考项目

- [OTeePee](https://github.com/sushiselite/oteepee)：macOS 15+ 菜单栏应用，读取 `~/Library/Messages/chat.db`，检测 OTP 格式，并复制到剪贴板。
- [imsg](https://github.com/openclaw/imsg)：更健壮的 Messages 数据库读取和监听实现，对理解 `chat.db`、文件系统事件和 Full Disk Access 很有帮助。
- [Faktor](https://github.com/nate-parrott/faktor)：面向浏览器的 OTP 自动填充系统，由 macOS app 配合 Chrome extension 工作。
- [XposedSmsCode](https://github.com/magisk317/XposedSmsCode)、[smscode-core](https://github.com/magisk317/smscode-core) 和 [smscode-rules](https://github.com/magisk317/smscode-rules)：中文短信验证码解析规则的重要参考。

## 开源许可

OTPilot 使用 [MIT License](LICENSE) 发布。

## 备注

OTPilot 首次启动时会从 Messages 当前最新的一行开始监听，所以不会扫描历史短信。之后如果想忽略旧消息，可以点击 `Skip Old` 把游标重置到当前最新消息。

自动粘贴仍然依赖当前焦点：验证码到达时，目标输入框必须已经处于聚焦状态。OTPilot 现在可以在焦点明显不是可编辑文本框时避免盲目发送 Command-V，但它还不能自己判断网页上哪一个输入框才是正确目标。
