#!/bin/bash
export HTTPS_PROXY=http://127.0.0.1:1090
export HTTP_PROXY=http://127.0.0.1:1090
export GIT_SSL_NO_VERIFY=1

git push -u origin feature/gaming-mode-toggle 2>&1

gh pr create \
  --repo noah-nuebling/mac-mouse-fix \
  --head miguelAngelo1999:feature/gaming-mode-toggle \
  --base master \
  --title "Add 'Toggle Mac Mouse Fix' button action (gaming mode)" \
  --body "Adds a button action that toggles all MMF interception on/off.

Uses the existing scrollKillSwitch + buttonKillSwitch config keys. Press the mapped button to disable MMF, press again to re-enable.

Use case: gaming, or any situation where you need raw mouse input without MMF processing.

Minimal implementation — 4 files, ~20 lines of new code." 2>&1
