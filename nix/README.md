This directory contains all nix-related (esp. NixOS) files.

Normally, I would have placed these directories on the same level as flake.nix, but:

- I want ./flake.nix at root for easier imports
- As this is a git-monorepo for my WHOLE server setup,
  (i.e. also including systems without NixOS)
  it also contains files for different systems.
  These should be separated from nix files, in general.
