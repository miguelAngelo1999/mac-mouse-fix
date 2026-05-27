#!/bin/bash
export HTTPS_PROXY=http://127.0.0.1:1090
export HTTP_PROXY=http://127.0.0.1:1090
export GIT_SSL_NO_VERIFY=1

git push -u origin feature/stop-scroll-action 2>&1

gh pr create \
  --repo noah-nuebling/mac-mouse-fix \
  --head miguelAngelo1999:feature/stop-scroll-action \
  --base master \
  --title "Add 'Stop Scroll' button action to arrest momentum" \
  --body "Adds a new one-shot button action: **Stop Scroll**

Maps to any button. When pressed, immediately cancels any ongoing scroll animation — like touching a trackpad surface to stop a page from coasting.

Useful for users with free-spinning scroll wheels who want a dedicated button to stop momentum without scrolling in the opposite direction.

Implementation: calls \`[Scroll resetState]\` which cancels the animator and stops momentum scroll." 2>&1
