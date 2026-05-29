# Continuation Prompt for Mac Mouse Fix Fork

## Context

I'm working on a fork of Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix) with additional features. The project is at `~/CodingProjects/mac-mouse-fix/mac-mouse-fix/` on macOS (M2 Max, macOS 26.5).

## Repo Structure

- **Branch `personal`** — my combined fork with all features, builds with: `xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App" -configuration Debug DEVELOPMENT_TEAM=4689N2Z98S CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build`
- **Branch `logitech-cid-reprog-controls`** — base for new feature branches
- Each feature gets its own branch off `logitech-cid-reprog-controls`, then cherry-picked into `personal`
- PRs go to `noah-nuebling/mac-mouse-fix` from `miguelAngelo1999/mac-mouse-fix`
- Push requires proxy: `HTTPS_PROXY=http://127.0.0.1:1090 GIT_SSL_NO_VERIFY=1`
- Launch app: `bash launch.sh`

## What's Done

- ✅ Logitech HID++ CID reprog (extra buttons via BT — USB receiver still TBD)
- ✅ Volume/brightness control (scroll + drag, CoreAudio + DDC + OSD HUD)
- ✅ Momentum arrest (3 modes: off, direction change, hard stop for free-spin wheels)
- ✅ Arrow key scroll effects (timeline scrubbing)
- ✅ Stop Scroll button action
- ✅ Gaming mode toggle (disable/enable MMF)
- ✅ Window Move drag
- ✅ Window Resize scroll
- ✅ Rotate & Zoom combined drag (with Shift-snap to 90°, pointer freeze, axis hysteresis)
- ✅ CID auto-reconnection on device switch (3s gap detection + 30s timer)
- ✅ FORCE_LICENSED + "MichaelAngelo's fork" branding

## What's Left (from FUTURE_FEATURES.md)

### High Priority
1. **USB Receiver CID support** — Unifying receiver needs different approach. The raw 0xFF00 interface can't be opened (exclusive access). Need to either:
   - Parse HID++ reports from the mouse interface (usage page 1, usage 2) where they might be forwarded
   - Or use a different IOKit approach (IOServiceOpen on the USB device directly)
   - Reference: Solaar uses hidraw on Linux, SteerMouse somehow does it on macOS

2. **Logitech thumb button as modifier layer** — hold thumb to change what all other buttons/scroll do. Needs changes to the modifier system in `Modifiers.m` / `Remap.m`.

### Medium Priority
3. **Notification Centre swipe** — simulate two-finger swipe from right edge
4. **Force Touch / Lookup simulation** — map button to force touch event
5. **Scroll on dock icon to cycle app windows**
6. **Scroll on menu bar to change audio output device**

### Nice to Have
7. **Inertia injection** — trailing momentum coast after fast scrolling stops
8. **Per-app momentum duration tuning**
9. **Visual indicator in menu bar showing active modifier/mode**
10. **Import/export button configs as JSON**

## Key Architecture Notes

- Scroll effects: add enum to `ScrollModifiers.h`, string constant to `Constants.h`, case to `ScrollModifiers.swift`, config in `ScrollConfig.swift`, output type + handler in `Scroll.m`, UI in `RemapTableTranslator.m`
- Drag effects: create plugin implementing `ModifiedDragOutputPlugin` protocol, add type constant to `Constants.h`, register in `ModifiedDrag.m`, add to drag effects table in `RemapTableTranslator.m`
- Button actions: add type to `Constants.h`, handler in `Actions.m`, UI entry in one-shot effects table in `RemapTableTranslator.m`
- New files need pbxproj patching (use Python script pattern from existing patches)
- Localization: add to `Localization/en.lproj/Localizable.strings`
- Build log goes to `build.log`, check with `grep "BUILD SUCCEEDED\|BUILD FAILED" build.log`

## Known Issues

- Toggle on/off doesn't work reliably in debug builds (bundle ID mismatch with login item system)
- CID buttons lost when switching mouse between computers — 30s timer + 3s gap detection helps but isn't instant
- USB Unifying receiver CID not working (exclusive access issue on 0xFF00 interface)
- The stray helper from the installed app keeps respawning — disable it from System Settings > Login Items before testing
