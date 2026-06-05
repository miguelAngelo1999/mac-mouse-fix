# Mac Mouse Fix — Next Session Prompt

Paste this at the start of the next chat:

---

I'm working on my Mac Mouse Fix fork at `~/CodingProjects/mac-mouse-fix/mac-mouse-fix/`. Branch: `smart-modifier-detection`. 

Read `.kiro/steering/brightness-ddc.md` for protected code context.

## Tasks (priority order)

### 1. Finish GDrive Auto-Updater
- DMG already uploaded: **ID `1tLVKTV-BjTkWyAMZ7dxc0imwQpk_uc3K`**
- URL: `https://drive.google.com/uc?export=download&id=1tLVKTV-BjTkWyAMZ7dxc0imwQpk_uc3K`
- Create `appcast.xml` (Sparkle format), upload to GDrive
- Wire Sparkle: set `SUFeedURL` in Info.plist to appcast GDrive URL
- Re-enable updater in `App/AppDelegate.m` (currently commented out)
- Remove DSA key checking (ad-hoc signed, no code signing verification)
- GDrive upload pattern: token at `~/vcf/gdrive_token.pickle`, proxy `127.0.0.1:9090`, disable SSL verify, upload to My Drive (not shared drive)

### 2. Merge Upstream (Noah's latest)
- Remote already added: `upstream` → `https://github.com/noah-nuebling/mac-mouse-fix.git`
- Already fetched. Merge base: commit `7969b9beda` (3.0.8 release)
- 1,839 commits behind (1,252 automated Acknowledgements, ~200 real — mostly translations + minor UI)
- **Core scroll/drag/buttons barely changed** (57 ins / 151 del in 16 files)
- Strategy: `git merge upstream/master`, resolve conflicts keeping our features, take their translations
- After merge, cherry-pick from:
  - `upstream/tahoe-symbols` — macOS Tahoe SF Symbol compat (2 commits)
  - `upstream/feature-scroll-capture-notifications` — scroll crash recovery

### 3. AI-Translate New Strings
- After merge, translate our new strings into all supported languages
- New strings to translate: Volume ↕, Brightness ↕, Volume ↔, Brightness ↔, Volume ↕ & Brightness ↔, Brightness ↕ & Volume ↔, Notification Center (drag effect names + hints)
- Update all `.lproj/Localizable.strings` files

### 4. (If time) Modifier Buttons
- Want buttons 4/5/8 to act as modifiers for buttons 1/2/3/6/7
- Native `ButtonModifiers` system exists in `Buttons.swift` — just needs proper activation
- Previous `ModTapCoordinator` approach broke primary buttons — DON'T use it
- Need to study `ClickCycle` + `ButtonModifiers` interaction carefully

## Build Commands
```bash
# Debug build (local dev)
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App" -configuration Debug DEVELOPMENT_TEAM=4689N2Z98S CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build

# Launch
bash launch.sh

# Distribution (universal, ad-hoc signed)
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App" -configuration Release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES DEVELOPMENT_TEAM="" build
# Then: codesign --force --deep --sign - "$APP_PATH"
```

## Current Version: 3.1.0-beta1

## Key Files (don't break these)
- `Helper/Core/Scroll/ScrollOutputUtility.m` — brightness, volume, OSD, DDC
- `Helper/Core/Drag/ModifiedDragOutputVolumeBrightness.m` — combined drag modes
- `Helper/Core/Drag/ModifiedDragOutputNotificationCenter.m` — NC interactive drag
- `Shared/Constants.h` — drag type constants
