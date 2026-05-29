#!/bin/bash
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App" -configuration Debug DEVELOPMENT_TEAM=4689N2Z98S CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build 2>&1 | tee build.log | tail -3
grep "error:" build.log | head -5
grep "BUILD SUCCEEDED\|BUILD FAILED" build.log
