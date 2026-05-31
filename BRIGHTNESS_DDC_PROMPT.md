# Brightness DDC — Implementation Complete

## Status: DONE ✓

All brightness features are implemented and working. See `.kiro/steering/brightness-ddc.md` for architectural details.

## What Works

- **Samsung (DDC)**: EDID-matched IOAVService, VCP 0x10 read/write, combined hw+sw dimming to full black
- **Dell (DisplayServices)**: 4x multiplier for responsiveness, combined hw+sw dimming below zero
- **Built-in display**: Native DisplayServices + native OSD
- **Custom OSD overlay**: Shows monitor name + brightness bar on external displays (macOS Tahoe broke native OSD for externals)
- **Display detection**: EDID-based scoring, cache invalidation on display reconfig
- **Drag targeting**: Display captured at drag start, explicit ID passed throughout
- **Combined modes**: "Volume ↕ & Brightness ↔" and "Brightness ↕ & Volume ↔" with smart axis hysteresis

## Drag Modes Available

| Mode | Vertical | Horizontal |
|------|----------|------------|
| Volume ↕ | volume | — |
| Brightness ↕ | brightness | — |
| Volume ↔ | — | volume |
| Brightness ↔ | — | brightness |
| Volume ↕ & Brightness ↔ | volume | brightness |
| Brightness ↕ & Volume ↔ | brightness | volume |

## Known Limitations

- macOS Tahoe removed the native brightness OSD for external monitors (Apple broke it, not us)
- Some Dell firmware won't go below ~1-2% via DisplayServices (hardware limit)
- DDC communication has inherent latency (~50ms per read, writes are async)
- Software gamma dimming resets on sleep/wake (re-applied on next brightness change)
