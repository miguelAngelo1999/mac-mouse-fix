#!/bin/bash
for f in $(git diff --name-only --diff-filter=U); do
    sed -i '' '/^<<<<<<< HEAD$/d' "$f"
    sed -i '' '/^=======$/d' "$f"
    sed -i '' '/^>>>>>.*/d' "$f"
    git add "$f"
done
git cherry-pick --continue --no-edit
