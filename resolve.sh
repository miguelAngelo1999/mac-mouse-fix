#!/bin/bash
for f in App/UI/Main/Tabs/ButtonTab/RemapTable/RemapTableTranslator.m Helper/Core/Actions/Actions.m Localization/en.lproj/Localizable.strings Shared/Constants.h; do
    sed -i '' '/^<<<<<<< HEAD$/d' "$f"
    sed -i '' '/^=======$/d' "$f"
    sed -i '' '/^>>>>>.*/d' "$f"
    git add "$f"
done
git cherry-pick --continue --no-edit
