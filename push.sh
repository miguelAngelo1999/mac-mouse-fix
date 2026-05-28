#!/bin/bash
export HTTPS_PROXY=http://127.0.0.1:1090
export HTTP_PROXY=http://127.0.0.1:1090
export GIT_SSL_NO_VERIFY=1
git add -A && git commit --amend --no-edit 2>/dev/null
git push origin personal --force 2>&1
