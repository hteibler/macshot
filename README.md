# macshot

A native macOS menu bar app that captures a window or the full screen to a
PNG on a global hotkey, with a configurable destination folder,
folder/filename templates, and hotkeys.

## Status

Core features are implemented: window capture, full-screen capture,
configurable hotkeys, folder/filename templates with filters, launch at
login, and optional copy-to-clipboard. See:

- [SPEC.md](SPEC.md) — requirements
- [CONTEXT.md](CONTEXT.md) — current milestone and implementation notes
- [TODO.md](TODO.md) — task checklist
- [AGENTS.md](AGENTS.md) — contribution/AI-coding guidelines

## Distribution

macshot is distributed as source via this GitHub repository only — build
it yourself (see below). There's no DMG/pre-built release. The repository
is currently **private**; the clone URL below only works for accounts with
access until/unless that changes.

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

## Running

macshot runs as a menu bar–only app (no Dock icon) — look for the camera
icon in the menu bar after launch. The first capture attempt triggers a
Screen Recording permission prompt (System Settings → Privacy & Security
→ Screen Recording); grant it and try the hotkey again. Click the menu bar
icon → Settings to configure the root folder, folder/filename templates,
hotkeys, and clipboard/login behavior.

## License

MIT — see [LICENSE.md](LICENSE.md).
