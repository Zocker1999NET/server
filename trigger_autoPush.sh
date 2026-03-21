#!/usr/bin/env bash

set -euo pipefail

current_branch=$(git branch --show-current)
if [[ "$current_branch" == "staging" ]]; then
    git push
fi

exec ssh -t root@fde3:b424:b5ce:1:be24:11ff:feb5:580c "systemctl start srv-autoPush.service && journalctl --follow --unit=srv-autoPush.service"
