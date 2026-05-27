#!/bin/bash
sed -i '' '/^<<<<<<< HEAD$/d' "App/UI/Main/Tabs/ButtonTab/RemapTable/RemapTableTranslator.m"
sed -i '' '/^=======$/d' "App/UI/Main/Tabs/ButtonTab/RemapTable/RemapTableTranslator.m"
sed -i '' '/^>>>>>.*/d' "App/UI/Main/Tabs/ButtonTab/RemapTable/RemapTableTranslator.m"

sed -i '' '/^<<<<<<< HEAD$/d' "Helper/Core/Drag/ModifiedDrag.m"
sed -i '' '/^=======$/d' "Helper/Core/Drag/ModifiedDrag.m"
sed -i '' '/^>>>>>.*/d' "Helper/Core/Drag/ModifiedDrag.m"

sed -i '' '/^<<<<<<< HEAD$/d' "Mouse Fix.xcodeproj/project.pbxproj"
sed -i '' '/^=======$/d' "Mouse Fix.xcodeproj/project.pbxproj"
sed -i '' '/^>>>>>.*/d' "Mouse Fix.xcodeproj/project.pbxproj"

sed -i '' '/^<<<<<<< HEAD$/d' "Shared/Constants.h"
sed -i '' '/^=======$/d' "Shared/Constants.h"
sed -i '' '/^>>>>>.*/d' "Shared/Constants.h"

git add -A
git cherry-pick --continue --no-edit
