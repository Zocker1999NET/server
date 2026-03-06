#!/usr/bin/env bash
# (shebang not used by Nix writeShellApplication, but by IDE)

set -euxo pipefail

requiredConfigs=(
    CFG_repositoryLocal
    CFG_repositoryRemote
    CFG_gpgSignFingerprint
    CFG_devKeyPath
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
# shellcheck disable=SC2154
gpgSignFingerprint="${CFG_gpgSignFingerprint}"  # must be all CAPS
# shellcheck disable=SC2154
devKeyPath="${CFG_devKeyPath}"

repoSrcBranch="${CFG_repositorySourceBranch:-staging}"
repoOrigin="${CFG_repositoryOrigin:-origin}"
repoDestBranch="${CFG_repositoryDestBranch:-main}"

# configure Git to use correct SSH key
export GIT_SSH_COMMAND="ssh -i ${devKeyPath@Q}"

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
git reset --hard  # ignore any pending changes from former (failed) runs
git switch "$repoSrcBranch"
git reset --hard "$repoOrigin/$repoSrcBranch"

# verify that staging is after main
if ! git merge-base --is-ancestor "$repoOrigin/$repoDestBranch" HEAD; then
    echo "branch $repoDestBranch not an ancestor of $repoSrcBranch; would not be allowed to push" >&2
    exit 2
fi

# verify that every commit along in staging is signed by correct key
for commit in $(git rev-list "$repoOrigin/$repoDestBranch"..HEAD); do
    if ! (git verify-commit --raw "$commit" 2>&1 | grep --extended-regexp '^\[GNUPG:\] VALIDSIG '"$gpgSignFingerprint"' .+ '"$gpgSignFingerprint"'$'); then
        echo "failed to verify signature of commit $commit" >&2
        echo "expected to find signature by ID $gpgSignFingerprint" >&2
        git verify-commit --raw "$commit" >&2 || true
        exit 2
    fi
done

# apply updates
export CI_MODE=1 # build locally, not on remotes

if ./tests.sh; then
    # when successfully finished
    git branch --force "$repoDestBranch"
    git push "$repoOrigin" "$repoDestBranch"
fi
