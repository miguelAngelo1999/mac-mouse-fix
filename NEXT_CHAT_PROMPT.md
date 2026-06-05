# Next Session: Auto-Updater + Upstream Merge

## Status: DMG uploaded to GDrive ✓

**DMG File ID:** `1tLVKTV-BjTkWyAMZ7dxc0imwQpk_uc3K`
**DMG URL:** `https://drive.google.com/uc?export=download&id=1tLVKTV-BjTkWyAMZ7dxc0imwQpk_uc3K`

## Remaining Steps for Updater

1. Create `appcast.xml` with Sparkle format pointing to the DMG URL above
2. Upload `appcast.xml` to GDrive, get its file ID
3. Set `SUFeedURL` in Info.plist to the appcast.xml GDrive URL
4. Re-enable Sparkle in AppDelegate.m
5. Remove DSA signature checking (we're ad-hoc signed)
6. Test: build, install old version, verify it detects and installs update

## GDrive Upload Script
- `upload_to_gdrive.py` in project root — works with proxy at 127.0.0.1:9090
- Uses token at `~/vcf/gdrive_token.pickle`
- Uploads to My Drive (shared drive had permission issues)

## Priority 2: Upstream Merge

### Status
- Merge base: 3.0.8 release (commit 7969b9beda)
- 1,839 commits behind (1,252 automated, ~200 real — mostly localization)
- Core files barely changed upstream (57 ins / 151 del in Scroll/Drag/Buttons)
- Manageable merge — main conflicts in AppDelegate, RemapTableTranslator, Constants, pbxproj, .strings

### Strategy
1. Create `upstream-merge` branch
2. `git merge upstream/master`
3. Resolve conflicts (keep our features, take upstream translations)
4. Test build

### Interesting Upstream Branches to cherry-pick
- `upstream/tahoe-symbols` — macOS Tahoe SF Symbol compat
- `upstream/feature-scroll-capture-notifications` — scroll crash recovery

## Priority 3: Modifier Buttons
- Native ButtonModifiers system exists, needs proper activation approach
- Don't use ModTapCoordinator (broke primary buttons)
- Study ClickCycle + ButtonModifiers interaction more carefully
