---
applyTo: 'nix/nixos*/**/*.nix,nix/modules/**/*.nix'
---

# NixOS module writing conventions (local)

Personal best practices distilled from reviewing label config, option ordering, comments & refactors in this repo.

## Comments

- One line, or as close to it as possible. State only the **why** — never the what (the code below already says that).
- Drop only **obvious** consequences — those trivially derivable from the mechanism (e.g. disabling privacy extensions only controls private-address rotation, common knowledge/easy lookup). For options with multiple or non-obvious consequences, comment the specific consequence that must be prevented.
- No filler words ("this is because", "which is the reason that", "in order to"). Telegraphic style is fine.
- Use common abbreviations only (`ddns`, `TSIG`, `AXFR`, `v6`, `AuthN`/`AuthZ` with that capitalization); do not invent non-standard ones (`2ndaries`) — prefer dropping the word instead.
- A custom option or unusual setting gets exactly one such comment at the point of definition.
- Reference links (Hetzner docs, RFCs) go next to the data they justify, not inline into module bodies.

## Local order & grouping inside a module block

- Do **not** reorder existing code unless explicitly requested — a different order may be justified.
- When inserting between existing attrs, derive the ordering logic in use (prefer commented order logic, otherwise infer) and insert accordingly.
- For fully new entries, do not infer a "better" order yourself; only deviate from this policy when the user actively requests it.
- Preferred target order (used when creating new blocks or when the user asks to order):
  - `enable` first (NixOS-wide convention)
  - most important/fundamental options — only those explicitly listed here count as such
    - `networking.hostName` & `networking.domain` written adjacent so the FQDN reads in one pass
  - alphabetical
- One-off comments must move with their option when it is relocated; keep the comment directly above the line it explains.
- Multi-module files (host configs with `modules = [ … ]` list): order the list logically (service wiring → base config → hardware profile → install state), as in `nix/nixos/de.6nw/pve.boreth/dns/default.nix`.

## Secrets wiring

- Secrets under `secrix` always get a comment with the creation command (how to recreate/rotate), not just what the file is.
- Env-like secrets go through the service's generic option (e.g. `envVarFiles` from the reflector module) instead of bespoke wrapping in the host config.

## Style

- No gratuitous renames in edits — check `git diff` for unintended changes (name churn, comment rewording you weren't asked to touch).
- Small fixes stay small: do not expand a bug fix into a generalization unless requested. Re-expansion proposals go in the reply text, not the diff.
- `example`, `default` & `defaultText` in option declarations take real Nix values; the doc renderer evaluates them, so any value usable as `default` needs no wrapper.
- Use `literalExpression` only where the value is not evaluable by the module system (references `pkgs`, `config`, …) or its rendering would be unclear — apply the same test to `example` as to `default`: if it would need `defaultText` were it the default, it needs `literalExpression` as `example`. Plain-JSON-ish structure never needs a wrapper.
- When updating this or the sibling `nix-with-and-inherit.instructions.md` keep wording terse, same style as there: header level 1 title, then short bullet lists.
