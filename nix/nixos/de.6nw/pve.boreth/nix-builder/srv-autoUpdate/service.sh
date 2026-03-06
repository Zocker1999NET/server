#!/usr/bin/env bash
# (shebang not used by Nix writeShellApplication, but by IDE)

set -euxo pipefail

requiredConfigs=(
    CFG_repositoryLocal
    CFG_repositoryRemote
)
for name in "${requiredConfigs[@]}"; do
    if [[ ! -v "$name" ]]; then
        echo "missing environment variable: $name" >&2
        exit 2
    fi
done

# shellcheck disable=SC2154
repoLocal="$CFG_repositoryLocal"
# shellcheck disable=SC2154
repoRemote="$CFG_repositoryRemote"

repoSrcBranch="${CFG_repositorySourceBranch:-main}"
repoOrigin="${CFG_repositoryOrigin:-origin}"
repoWorkingBranch="${CFG_repositoryWorkingBranch:-autoUpdateWIP}"
repoDestBranch="${CFG_repositoryDestBranch:-autoUpdated}"

# jump into repo
if [[ ! -d "$repoLocal" ]]; then
    echo "cannot find local mirror at $repoLocal"
    echo "clone repo from $repoRemote"
    git clone --origin "$repoOrigin" -- "$repoRemote" "$repoLocal"
fi
cd "$repoLocal"

# configure repo correctly
git remote set-url "$repoOrigin" "$repoRemote"
git fetch "$repoOrigin"
git reset --hard # ignore any pending changes from former (failed) runs
git switch "$repoSrcBranch"
git reset --hard "$repoOrigin/$repoSrcBranch"
git switch --force-create "$repoWorkingBranch"

# apply updates
export CI_MODE=1 # build locally, not on remotes

if ./update.sh && ./tests.sh; then
    # when successfully finished
    git branch --force "$repoDestBranch"
fi
