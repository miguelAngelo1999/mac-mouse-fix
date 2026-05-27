#!/usr/bin/env python3
"""Replace Noah's bundle IDs with a personal one for local builds."""
import os

OLD = "com.nuebling.mac-mouse-fix"
NEW = "com.virgoh.mac-mouse-fix"

files = [
    "Mouse Fix.xcodeproj/project.pbxproj",
    "App/SupportFiles/Info.plist",
    "App/SupportFiles/App.entitlements",
    "Helper/SupportFiles/Info.plist",
    "Helper/SupportFiles/Helper.entitlements",
]

for path in files:
    if not os.path.exists(path):
        print(f"SKIP (not found): {path}")
        continue
    with open(path) as f:
        content = f.read()
    if OLD not in content:
        print(f"SKIP (no match): {path}")
        continue
    content = content.replace(OLD, NEW)
    with open(path, "w") as f:
        f.write(content)
    print(f"Updated: {path}")
