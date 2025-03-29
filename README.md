# 6nw.de NixOS Configurations


This is my all-in-one repository for my complete server setup.
It should contain all information to also be used for bootstraping this setup.

This is for my server setup after deploying it locally on a Proxmox node, starting in 2024-07.


## Interesting for All

This section tries to highlight packages, scripts, modules & so on
which could be highly interesting to many NixOS users,
even if they do not just want to replicate my server & client setup 1:1.

### Packages

These packages should be useable & practable on their own or in fairly common setups,
without fully submitting to the way I implement & configure my stuff.
All of these packages can easily be included by importing the output `overlays.fromFlake` as nixpkgs overlay.

- **nft-update-addresses**:
    This service enables easy writing of nftables rules which automatically adapt to dynamically changing IP addresses & prefixes.
    Read more about it [here](./nix/packages/nft-update-addresses/default.nix) in `meta.longDescription`.
    - NixOS module `services.nft-update-addresses` inclusive, see [here](./nix/nixos-modules/packages/nft-update-addresses.nix)

### NixOS modules

This flake includes some cool extensions which might be useful to all.
I have not documented all of them here yet,
but as all of those should be safe-guarded
by their own module options
or should otherwise only trigger under reasonable cirumstances,
I invite you to import all of those by adding `nixosModules.withDepends` to your imports
(no gurantees given. This also then includes modules from others mine build upon).

Some module groups are marked as "intend to upstream" because I want to upstream those to nixpkgs.
These may also be imported by paths directly, as they should work independently of most other modules.

Notable module implementations are:

- **assertions**: adds reasonable assertions checking for common mistakes I ran into, which had no assertions in nixpkgs yet (intend to upstream)
- **extends**: adds useful options to already existing nixpkgs modules (intend to upstream)
- **overlays**: need to be imported by path or variable directly, implement overlays from this flake in more restricted ways
    by setting package options instead of applying them on all packages (hence avoiding huge recompiles)

### NixOS "configurations"

Most of them are implemented as modules,
but given their size & ambitious goals,
I chose to classify those differently.

- **router**: a Router framework for NixOS systems (read its own section [here](./nix/nixos-modules/router/README.md))
- **vmDisko**: defines reasonable default disko disk layouts, intended for VMs, with state option to allow updating layouts for future systems [*WIP = untested!*]


## Structure of this repo

Files are mostly separated by which service can read them.
Each service directory is then,
in a strucutre preferred by that service,
further structured into concepts.
Global concepts are explained in the [documentation](./docs).


## Steps for Bootstraping

For bootstraping from a clean state.
Steps might be some kind of fuzzy, depending on the complexity.

(**TODO** add list of steps)


## License

I assume being the only copyright holder for most content in this repository.
The only exceptions to this are snippets which are marked with a comment containing ` source:`
which were taken from freely available sources.
These snippets may be also available under a different, less-restrictive license.

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
I grant you to use the whole content in this repository under the terms of
the GNU Affero General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.
A copy of the GNU AGPL 3.0 License is attached in the [LICENSE file](./LICENSE.txt).

Some files might be also licensed individually under more permissive licenses.
You may find these files by searching for individual `SPDX-License-Identifier`.

(The following subsections are **mere explanations** of the effects of the AGPL
or of possibilities I want to inform you about.
**Neither do those subsections define the actual legal situation,
nor can they considered to be legal advice in any form.**)

### Reasoning & Contributions

I chose this license to ensure my code can be freely used for benefit of the public
while requiring its users to share their improvements with the public as well.

But, I consider this repository to be mine,
especially because I want myself to not be bounded by the requirements of the AGPL
when deploying the configurations described here.
This means I will refrain from accepting contributions directly to this repository.
If you still want to directly contribute, I require you to license your contribution under a more permissive license
(similar to the requirement of signing a [CLA](https://en.wikipedia.org/wiki/Contributor_License_Agreement)).
I am aware of the controversies around CLAs & I also avoid contributing to CLA-requiring projects myself.

I chose the AGPL because some work in this repository consumed a very large proportion of my time,
and I do want to avoid to lose control over the entirity of it.
This could happen in theory
when accepting outside contributions
without having clearly defined borders first.
And I require the users of my code here to abide to the AGPL
because I also want them to be required to publish their improvements to the public,
especially if they intend to make money with these very valuable parts of my code.

Despite these requirements,
please continue to understand my act of publishing repository as a donation.
Because, I still could have decided to not publish this repository,
making it impossible for others to learn from my achievements.
And thus making it impossible to ask others for more permissive use of some parts.

### Possible Excemptions for the FLOSS Community

I acknowledge that there are also some parts in this repository
which are more useful to the public with outside contributions
and also probably when licensed under more permissive licenses.
Also, there are some parts in this repository which I already intend to upstream,
in most cases this means pushing them to [nixpkgs](https://github.com/NixOS/nixpkgs).

If you think you have identified such part,
and you want to contribute to that part
(and this part is not already licensed more permissively),
you may ask for me for permission to grant the whole community
further use of that part under a more permissive license, such as MIT.

Also (**without guranteeing you that**, feel free to ask for excemptions to be legally safe),
I will not consider re-distributing small snippets from my code here as copyright violations.
And I will most probably not sue you,
even if you are using my code here for commercial uses,
as long as the parts you are using are not making up a possible key selling point of a service or product you provide
(e.g. using a modified mgmt ISO to get your actual work done).
And you can reduce that possibility by contributing your overall improvements back,
under a reasonable FLOSS license,
not necessarily to this repository.

### Warning on Generated Outputs

Be aware that any artifacts produced by code in this repository may also be based on content
which was published under a license not being compatible to the license of this repository
(e.g. by integrating proprietary components into a final system configuration).
So the freedoms provided by the AGPL may not be applicable to a whole output.

However, the restrictions of the AGPL might apply to some such artificats,
given that most of its parts are compiled for inclusion in the generated output.

Hence, overall, it might be possible that you are not allowed to redistribute some output in its completeness.
Further, since under the AGPL, you may not be allowed to provide a service based on code contained in this repository.
