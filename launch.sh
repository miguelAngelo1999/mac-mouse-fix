#!/bin/bash
pkill -f "Mac Mouse Fix" || true
pkill -f "Mac Mouse Fix Helper" || true
sleep 2
open -n ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/"Mac Mouse Fix.app"
