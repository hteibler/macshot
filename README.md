# macshot

A native macOS menu bar app that captures a window or the full screen on a
global hotkey, saving it as PNG, JPG, or GIF into a configurable folder
with configurable folder/filename templates.

## Status

Core features are implemented:

- Window capture and full-screen capture, each on its own independent
  global hotkey
- Output format is selectable — PNG, JPG (with adjustable quality), or GIF
- Folder/filename templates with placeholder tokens: date/time
  (`{YYYY}`/`{MM}`/`{DD}`/`{hh}`/`{mm}`/`{ss}`), the captured window's
  `{title}`/`{app}`, a persisted incrementing counter (`{NUM}`), and
  random alphanumeric strings of any length (`{RRR...}` — the number of
  `R`s sets the length)
- Search/replace filters on the rendered folder name, and nested
  subfolders by putting `/` directly in the folder name template
  (e.g. `{YYYY}/{MM}-{DD}`)
- An in-app Help sheet listing every template token
- Optional save notifications (banner and/or sound, independently
  toggleable) and copy-to-clipboard
- Launch at login

## Distribution

macshot is distributed via this GitHub repository — either as a signed,
notarized DMG from [Releases](https://github.com/hteibler/macshot/releases)
(no Gatekeeper warnings, just open and drag to Applications), or as
source you build yourself (see below).

## Requirements

- macOS 14.0 or later to run
- [Xcode](https://developer.apple.com/xcode/) 15 or later (developed with Xcode 26.6)
- [Homebrew](https://brew.sh) and [XcodeGen](https://github.com/yonaskolb/XcodeGen), to generate the Xcode project from `project.yml`:

  ```bash
  brew install xcodegen
  ```

## Build

```bash
git clone https://github.com/hteibler/macshot.git
cd macshot
xcodegen generate
```

This creates `macshot.xcodeproj`. Either:

- Open it in Xcode and press Run, or
- Build from the command line:

  ```bash
  xcodebuild -project macshot.xcodeproj -scheme macshot -configuration Debug build
  ```

  The built `.app` lands under Xcode's DerivedData
  (`~/Library/Developer/Xcode/DerivedData/macshot-*/Build/Products/Debug/macshot.app`).

If you edit `project.yml` (targets, settings, build phases), re-run
`xcodegen generate` to regenerate `macshot.xcodeproj` before building.

### Signed release build (maintainer only)

Producing the notarized DMG published in Releases requires a Developer ID
Application certificate (Apple Developer Program membership) and isn't
needed to just run or hack on macshot — a plain Debug build is fine for
that. For reference, the release process is:

```bash
xcodegen generate

xcodebuild -project macshot.xcodeproj -scheme macshot -configuration Release \
  archive -archivePath build/macshot.xcarchive

xcodebuild -exportArchive -archivePath build/macshot.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist

ditto -c -k --keepParent build/export/macshot.app build/macshot.zip
xcrun notarytool submit build/macshot.zip --keychain-profile "xcode" --wait
xcrun stapler staple build/export/macshot.app

# package into build/macshot-<version>.dmg with an Applications symlink, then:
codesign --sign "Developer ID Application: <Name> (<TeamID>)" --timestamp build/macshot-<version>.dmg
xcrun notarytool submit build/macshot-<version>.dmg --keychain-profile "xcode" --wait
xcrun stapler staple build/macshot-<version>.dmg
```

Using `xcodebuild ... build` directly (instead of `archive` +
`-exportArchive`) produces a binary notarization will reject — it's
missing a secure timestamp and carries the `get-task-allow` debug
entitlement, both of which the archive/export path strips.

## Running

macshot runs as a menu bar–only app (no Dock icon) — look for the camera
icon in the menu bar after launch. The first capture attempt triggers a
Screen Recording permission prompt (System Settings → Privacy & Security
→ Screen Recording); grant it and try the hotkey again. Click the menu bar
icon → Settings to configure the root folder, folder/filename templates,
output format, both hotkeys, and clipboard/notification/login behavior.
There's also a Help button in Settings listing every template token.

**Notifications require a real code signature.** The released DMG is
properly signed and this just works. If you're building from source
without a Development Team configured in Xcode (Settings → Accounts, then
select that team for the `macshot` target's signing), the app is signed
ad-hoc/locally only, and macOS's notification system won't authorize it —
the "Notify on Save" toggle will silently do nothing. A free Personal Team
is enough to fix it; everything else works fine without one.

## License

MIT — see [LICENSE.md](LICENSE.md).
