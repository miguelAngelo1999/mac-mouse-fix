#!/bin/bash
export HTTPS_PROXY=http://127.0.0.1:1090
export HTTP_PROXY=http://127.0.0.1:1090
export GIT_SSL_NO_VERIFY=1

git push -u origin feature/scroll-arrow-keys 2>&1

gh pr create \
  --repo noah-nuebling/mac-mouse-fix \
  --head miguelAngelo1999:feature/scroll-arrow-keys \
  --base master \
  --title "Add arrow key scroll effects for timeline scrubbing" \
  --body "Two new scroll effect modifications that convert scroll ticks into arrow key presses:

- **Arrow Keys (Vertical)**: scroll up/down → Up/Down arrow keys
- **Arrow Keys (Horizontal)**: scroll up/down → Right/Left arrow keys

One key press per scroll tick, no animation. Use cases:
- Timeline scrubbing in video players (QuickTime, YouTube, Premiere)
- Navigating slides in presentations
- Stepping through lists, code, etc.

Minimal implementation — reuses existing scroll effect modification infrastructure." 2>&1
