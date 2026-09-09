#!/usr/bin/env bash
# (shebang not used by Nix writeShellApplication, but by IDE)

set -euxo pipefail

requiredConfigs=(
    CFG_repositoryLocal
    CFG_repositoryRemote
    CFG_gcrootsDir
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
git bisect reset  # ignore any pending bisect from former (failed) runs
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

# prepare gcroots
# shellcheck disable=SC2154
gcrootsDir="$CFG_gcrootsDir"
gcrootsSuccess="$gcrootsDir/success"
gcrootsBuilds="$gcrootsSuccess/builds"
gcrootsWIP="$gcrootsDir/working"
if [[ -e "$gcrootsWIP" ]]; then
    rm --recursive "$gcrootsWIP"
fi
mkdir --parent "$gcrootsWIP"

# apply updates
export CI_MODE=1 # build locally, not on remotes
export CI_GCROOT="$gcrootsWIP"

if ./tests.sh --auto-bisect "$repoOrigin/$repoDestBranch"; then
    # when successfully finished
    mkdir --parent "$gcrootsSuccess"
    # merge the whole working dir into the persistent store
    cp --recursive --no-clobber "$gcrootsWIP/." "$gcrootsSuccess/"
    # working dir is fully consumed -> ensure it gets removed
    rm --recursive "$gcrootsWIP"
    # only prune builds: keep only newest commit, drop all older ones
    # (see ./tests.sh for exact reasoning)
    if [[ -d "$gcrootsBuilds" ]]; then
        # sort by creation date and delete all but the newest
        find "$gcrootsBuilds" -mindepth 1 -maxdepth 1 -type d -printf '%W@\t%p\0' \
            | sort --zero-terminated --numeric-sort \
            | head --zero-terminated --lines=-1 \
            | cut --zero-terminated --fields=2- \
            | xargs --null --no-run-if-empty rm --recursive
    fi
    # make nix remember GC roots at new locations, so they are not deleted by the next GC
    find "$gcrootsSuccess" -type l -print0 \
        | xargs --null --no-run-if-empty --replace={} nix-store --add-root {} --realise {}
    git branch --force "$repoDestBranch"
    git push "$repoOrigin" "$repoDestBranch"
fi

# do not clean up, so the results can be reused on the next run
