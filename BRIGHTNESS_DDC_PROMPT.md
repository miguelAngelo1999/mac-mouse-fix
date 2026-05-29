# Brightness DDC Fix — Samsung Monitor

## Context
I'm working on a fork of Mac Mouse Fix at `~/CodingProjects/mac-mouse-fix/mac-mouse-fix/` on macOS (M2 Max, macOS 26.5). Branch: `smart-modifier-detection`.

Build command: `xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App" -configuration Debug DEVELOPMENT_TEAM=4689N2Z98S CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build`

Launch: `bash launch.sh`

## Problem
The brightness drag control works for the Dell monitor (via `DisplayServicesSetBrightness`) but NOT for the Samsung monitor. The Samsung:
- `DisplayServicesGetBrightness` returns error code 1000 (not supported)
- Falls through to DDC path
- DDC path uses `avServiceForDisplay:` which only matches by "External" location string — can't distinguish between two external monitors
- MonitorControl CAN control the Samsung's brightness via DDC, so the hardware supports it

## Current Code
`Helper/Core/Scroll/ScrollOutputUtility.m` — the `adjustBrightnessByDelta:` method and `avServiceForDisplay:` method.

## What MonitorControl Does (source at `~/CodingProjects/mac-mouse-fix/MonitorControl/`)
- `MonitorControl/Support/Arm64DDC.swift` — `getServiceMatches(displayIDs:)` and `ioregMatchScore()`
- Iterates IORegistry tree finding all `DCPAVServiceProxy` entries
- For each, reads EDID UUID, product name, serial number from IORegistry properties
- Uses `CoreDisplay_DisplayCreateInfoDictionary(displayID)` to get EDID info from the CGDirectDisplayID
- Scores matches and assigns the correct IOAVService to each display

## What Needs to Be Done
1. Replace the naive `avServiceForDisplay:` (which just matches "External") with proper EDID-based matching
2. Use `CoreDisplay_DisplayCreateInfoDictionary` (private API, available on Apple Silicon) to get display info from CGDirectDisplayID
3. Compare EDID UUID or product name + serial from IORegistry `DCPAVServiceProxy` entries
4. Cache the mapping so we don't re-enumerate on every brightness adjustment

## Console Log Evidence
```
Brightness: delta=1.0467 accum=1.0562 display=4 builtIn=0
Brightness: DisplayServices get=1000 current=0.500
```
Display ID 4 is the Samsung. DisplayServices fails, DDC fallback runs but sends to wrong service.

## Also Fix
- The OSD HUD shows 0 all the time for external monitors — the `brightnessCache` starts at 50 but the OSD value calculation might be wrong, or the cache doesn't reflect actual brightness
- Consider reading current DDC brightness (VCP 0x10 Get) on first use to seed the cache

## Setup
- M2 Max MacBook Pro
- Dell external monitor (works via DisplayServices)
- Samsung external monitor (needs DDC, MonitorControl handles it fine)
- Both connected via USB-C/Thunderbolt
