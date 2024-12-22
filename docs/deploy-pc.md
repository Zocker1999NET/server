# Deployment Client

A deployment client has all software installed
required to automatically deploy changes to the server environment.

This might also be your current computer,
however that is discouraged
because a lot of bloat software is required.

The deployment client at least requires following tools (or other compatible solutions):

- Ansible
- OpenTofu
- OpenSSH

The solution for now is built on Debian.


## Debian

You have following requirements:

- on your local computer
    - Python3
    - SSH client
- another computer (can be a VM, but will be manually configured)
- recent Debian installation ISO
