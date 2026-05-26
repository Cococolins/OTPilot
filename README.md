# OTPilot

[中文](README.zh-CN.md) | English

OTPilot is a macOS 15 menu bar utility for SMS one-time passwords. It watches the local Messages database, extracts likely verification codes, copies the code to the clipboard, and can optionally paste it into the currently focused field.

It is designed for browsers like Dia, Chrome, and Arc where macOS does not provide Safari-style SMS code autofill.

## Features

- Menu bar app, no Dock icon.
- Reads incoming SMS/iMessage rows from `~/Library/Messages/chat.db`.
- Extracts common English and Chinese OTP formats.
- Copies detected codes to the clipboard.
- Optional auto paste using Command-V.
- Optional clipboard restore after 45 seconds.
- Notification feedback when a code is copied and still needs to be pasted.
- Optional launch at login.
- Starts monitoring automatically when the app opens by default.

## Requirements

OTPilot does not provide a notarized prebuilt release yet. For now, build it from source.

- macOS 15 or later.
- Messages configured on the Mac and SMS forwarding/iMessage sync enabled.
- Full Disk Access permission for OTPilot.
- Accessibility permission if `Auto paste` is enabled.
- macOS 15 SDK.
- Xcode or Apple Command Line Tools with `swift`, `make`, `codesign`, and standard macOS developer tools available.
- Optional but recommended: a local Apple Development signing identity. A free Apple ID development certificate is enough for local use; a paid Developer ID certificate is only needed for polished public distribution/notarization.

Check your local toolchain with:

```bash
swift --version
security find-identity -v -p codesigning
```

## Install And Run

### For Non-Technical Users

OTPilot is distributed as source code for now, not as a notarized `.app`.

1. Open the [v1.0 release](https://github.com/Cococolins/OTPilot/releases/tag/v1.0).
2. Download `OTPilot-v1.0-source.zip`.
3. Unzip the file.
4. Open the unzipped `OTPilot-v1.0` folder.
5. Double-click `Install OTPilot.command`.

If macOS says the script cannot be opened, right-click `Install OTPilot.command`, choose `Open`, then confirm. The installer opens Terminal, builds OTPilot, copies it to `/Applications/OTPilot.app`, and launches it.

If the installer says Swift or `make` is missing, install Apple's Command Line Tools first. To do that, press Command-Space, type `Terminal`, open the Terminal app, paste this command, and press Return:

```bash
xcode-select --install
```

macOS will show an installation prompt. Follow the prompt, then double-click `Install OTPilot.command` again.

### For Terminal Users

Run the install command from the project folder. For example, after cloning the repository:

```bash
git clone https://github.com/Cococolins/OTPilot.git
cd OTPilot
make install
```

If you downloaded the source as a ZIP, unzip it, open Terminal, `cd` into the unzipped `OTPilot` folder, then run:

```bash
make install
```

This builds the SwiftPM app, stages `dist/OTPilot.app`, signs it, copies it to `/Applications/OTPilot.app`, and launches the installed app.

You can also call the underlying script directly:

```bash
./script/build_and_run.sh --install
```

Use `--install` during development too. macOS privacy permissions are tied to app identity and path, so switching between `dist/OTPilot.app` and `/Applications/OTPilot.app` can make Accessibility or Full Disk Access look enabled while the running app is not actually trusted.

## Permissions

OTPilot needs Full Disk Access to read:

```text
~/Library/Messages/chat.db
```

Auto paste requires Accessibility permission because OTPilot sends a Command-V keyboard event to the currently focused app.

If auto paste does not work, check:

```bash
log show --last 5m --predicate 'subsystem == "app.otpilot.OTPilot"' --style compact
```

Expected auto-paste logs look like:

```text
Detected OTP ... autoPaste=true; accessibilityTrusted=true
Posted Command-V event
```

If the log says `Accessibility is not trusted`, remove any old OTPilot entry from System Settings, add `/Applications/OTPilot.app` again, and enable it.

Notifications intentionally do not include the OTP or sender. OTPilot shows a notification when it copies a code and leaves pasting to you. When auto paste succeeds, it does not show a notification because the paste action itself is the feedback.

## Signing

The build script prefers a local `Apple Development` signing identity if one exists, and falls back to ad-hoc signing only when no identity is available.

Stable signing helps macOS keep Full Disk Access, Accessibility, and Login Items permissions across app updates.

Ad-hoc signed local builds can run, but macOS may treat frequent rebuilds as a changed app identity. If permissions appear to reset after every build, use a stable Apple Development certificate and keep installing to `/Applications/OTPilot.app`.

For public GitHub releases, a Developer ID signed and notarized build would provide the cleanest first-launch experience. Without notarization, users may need to right-click Open or approve the app in Privacy & Security the first time.

To override signing:

```bash
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./script/build_and_run.sh --install
```

To override the bundle identifier for your own builds:

```bash
BUNDLE_ID="com.example.OTPilot" ./script/build_and_run.sh --install
```

## OTP Parsing

The parser is optimized for both English and Chinese SMS templates. It does not assume the code always appears after the keyword.

Supported examples include:

```text
【豆瓣网】豆瓣登录验证码：2463
【哔哩哔哩】597700短信登录验证码
[瑞幸咖啡] 验证码：088864
Use 837201 as your login code.
G-789012 is your Google verification code
```

The current strategy is:

1. Find verification keywords, including simplified/traditional Chinese variants.
2. Enumerate 4-8 character candidates near the keyword.
3. Filter likely date/time and URL tokens.
4. Rank 6-digit numeric codes first, then 4-digit, other numeric, and alphanumeric codes.

## Useful Commands

Build only:

```bash
make build
```

Install and launch:

```bash
make install
```

Verify process launch:

```bash
make verify
```

Stream app logs:

```bash
make telemetry
```

Inspect the running app path:

```bash
ps -axo pid,comm,args | rg 'OTPilot' | rg -v rg
```

Inspect code signature:

```bash
codesign -dv --verbose=4 /Applications/OTPilot.app 2>&1 | sed -n '1,90p'
```

## Prior Art

- [OTeePee](https://github.com/sushiselite/oteepee): macOS 15+ menu bar app that reads `~/Library/Messages/chat.db`, detects OTP patterns, and copies codes to the clipboard.
- [imsg](https://github.com/openclaw/imsg): robust Messages database reader and watcher. Useful for understanding `chat.db`, filesystem events, and Full Disk Access behavior.
- [Faktor](https://github.com/nate-parrott/faktor): browser-oriented OTP autofill system pairing a macOS app with a Chrome extension.
- [XposedSmsCode](https://github.com/magisk317/XposedSmsCode), [smscode-core](https://github.com/magisk317/smscode-core), and [smscode-rules](https://github.com/magisk317/smscode-rules): useful references for Chinese SMS-code parsing rules.

## Notes

OTPilot starts from the newest Messages row on first launch, so it does not scan old SMS history. Use `Skip Old` to reset the cursor to the current latest message.

Auto paste is focus-dependent: the target input field must be focused when the SMS arrives. If detection and Command-V logs appear but nothing pastes, the next likely improvement is a focused-field Accessibility API fallback.
