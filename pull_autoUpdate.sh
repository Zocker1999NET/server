#!/usr/bin/env bash

set -euo pipefail

if [[ -n "$(git status --untracked-files=no --porcelain)" ]]; then
    echo "working directory must be clean for pulling autoUpdate!" >&2
    exit 2
fi

git switch staging
git pull
git fetch nix-builder
git merge --ff-only nix-builder/autoUpdated
nix flake archive
git rebase --exec "git commit --amend --no-edit" origin/staging # sign commits with GPG (works because signing configured in .git/config
git push
