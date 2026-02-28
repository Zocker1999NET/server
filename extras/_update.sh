# regenerate all pinned files in this directory
# the command results are expected to be indempotent (i.e. only change the files when changes are required)

# jump to extras directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# GPG keys
gpg --armor --export 73D09948B2392D688A45DC8393E1BD26F6B02FB7 > ./gpg_myKey.gpg
gpg --armor --export 19C17AF30A1152D473A3849C28279F3E0A444E63 > ./gpg_archiveKey.gpg

