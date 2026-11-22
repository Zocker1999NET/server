---
applyTo: '**/*.nix'
---

# Nix with-expressions & inherit rules

- Never use `with` on top of a file or any large block (`submodule { … }`, lists, `{ … }` bodies).
- `with <attrset>;` changes name resolution for its **entire scope** — any unintended name resolves silently, errors surface elsewhere.
- Allowed `with` use: a **single expression only**, no nested blocks, e.g. `type = with types; listOf str;`.
- Everything else: qualify explicitly (`types.path`) or use `inherit` in a `let` at the top of the module.
- Prefer `inherit` over `lib.*` / `builtins.*` everywhere, even for single use. Inherit from the most specific sub-attrset:
  - `inherit (lib.options) mkOption mkEnableOption;`, `inherit (lib.lists) singleton;`, `inherit (lib.meta) getExe;`, `inherit (builtins) toJSON;` etc.
  - exception: `inherit (lib) types;` then caller-side `types.<name>` (never bare `submodule`, `str`, … — ambiguous & shadowing-prone).
    Reason: validating a single type is an easy list to keep, but skipping a single `types.` prefix produces silent, wrong results when a name collides with any outer binding; using `types.<name>` prevents this.
- Single types use `types.<name>`; only compound expressions (`listOf str`, ...) take a scoped `with types;`.
