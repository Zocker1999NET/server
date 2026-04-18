---
name: nix-basics
description: Explains the nix language, module system, flakes & some surroundings. A MUST READ when working on nix files or with nix.
---

# Nix Learnings

This document contains my learnings from reading nix.dev documentation about the Nix ecosystem.

## Table of Contents

1. [Nix Language Basics](#nix-language-basics)
   - [Basic Literals](#basic-literals)
   - [Functions](#functions)
   - [Control Flow](#control-flow)
   - [Libraries](#libraries)
   - [Impurities](#impurities)
   - [Derivations](#derivations)
2. [Module System](#module-system)
3. [Flakes](#flakes)
4. [callPackage Pattern](#callpackage-pattern)
5. [Best Practices](#best-practices)
6. [Shell Environments](#shell-environments)
7. [Pinning Nixpkgs](#pinning-nixpkgs)

---

## Nix Language Basics

### Overview

The Nix language is a domain-specific, purely functional, lazily evaluated, dynamically typed programming language designed for creating and composing *derivations* - precise descriptions of how contents of existing files are used to derive new files.

**Notable uses:**
- **Nixpkgs**: The largest, most up-to-date software distribution in the world
- **NixOS**: A Linux distribution configured fully declaratively using Nix language

### Key Concepts

#### Values and Data Types

- **Primitive types**: strings, integers, floats, booleans, null
- **Lists**: `[ 1 "two" false ]` - elements separated by whitespace
- **Attribute sets**: `{ a = "hello"; b = 2; }` - like JSON with functions
- **Recursive attribute sets**: `rec { one = 1; two = one + 1; }` - allows self-reference

---

### Basic Literals

#### String

Strings are enclosed in double quotes. They support:
- **String interpolation**: `"hello ${name}"`
- **Indented strings**: `''multi\nline\nstring''` - double single quotes for multi-line strings
- **Escape sequences**: `"\n\t\"`

#### Number

Numbers can be *integers* (like `123`) or *floating point* (like `123.43` or `.27e13`).

Integers in the Nix language are 64-bit [two's complement] signed integers, with a range of -9223372036854775808 to 9223372036854775807, inclusive.

> **Note**
> Negative numeric literals are parsed as unary negation of positive numeric literals.
> This means that the minimum integer `-9223372036854775808` cannot be written as-is as a literal, since the positive number `9223372036854775808` is one past the maximum range.

#### Path

*Paths* can be expressed by path literals such as `./builder.sh`.

A path literal must contain at least one slash to be recognised as such.
For instance, `builder.sh` is not a path - it's parsed as an expression that selects the attribute `sh` from the variable `builder`.

Path literals are resolved relative to their base directory.
Path literals may also refer to absolute paths by starting with a slash.

> **Note**
> Absolute paths make expressions less portable. In the case where a function translates a path literal into an absolute path string for a configuration file, it is recommended to write a string literal instead.

If the first component of a path is a `~`, it is interpreted such that the rest of the path were relative to the user's home directory.
For example, `~/foo` would be equivalent to `/home/user/foo` for a user whose home directory is `/home/user`.
Path literals that start with `~` are not allowed in pure evaluation.

Path literals can also include string interpolation, but at least one slash (`/`) must appear *before* any interpolated expression for the result to be recognized as a path:

```nix
./a.${foo}/b  # This is a path
a.${foo}/b    # This is a number division operation!
```

**Lookup Paths** like `<nixpkgs>` also resolve to path values:

```nix
<nixpkgs>     # Resolves to a path based on $NIX_PATH
<nixpkgs/lib> # Subdirectory
```

> **Warning**: Lookup paths are impurities - avoid in production code for reproducibility.

#### List

Lists are formed by enclosing a whitespace-separated list of values between square brackets:

```nix
[ 123 ./foo.nix "abc" (f { x = y; }) ]
```

This defines a list of four elements, the last being the result of a call to the function `f`. Note that function calls have to be enclosed in parentheses.

> **Note**: Lists are lazy in values but strict in length.

Elements in a list can be accessed using `builtins.elemAt`:

```nix
builtins.elemAt [ "a" "b" "c" ] 1  # "b"
```

#### Attribute Set

An attribute set is a collection of name-value-pairs called *attributes*, written enclosed in curly brackets (`{ }`):

```nix
{
  x = 123;
  text = "Hello";
  y = f { bla = 456; };
}
```

Attribute names and values are separated by `=`, with each value terminated by `;`.
Attribute names can be identifiers or arbitrary double-quoted strings.

**Nested attribute paths** can be written using dot notation:

```nix
{ a.b.c = 1; a.b.d = 2; }
# Equivalent to:
# {
#   a = {
#     b = {
#       c = 1;
#       d = 2;
#     };
#   };
# }
```

**Attribute selection** uses the `.` operator:

```nix
{ a = "Foo"; b = "Bar"; }.a  # "Foo"

# With default value:
{ a = "Foo"; b = "Bar"; }.c or "Xyzzy"  # "Xyzzy"
```

**Arbitrary string attribute names**:

```nix
{ "$!@#?" = 123; }."$!@#?"  # 123

let bar = "bar"; in
{ "foo ${bar}" = 123; }."foo ${bar}"  # 123
```

**Dynamic attribute names with interpolation**:

```nix
let bar = "foo"; in
{ foo = 123; }.${bar}  # 123

let bar = "foo"; in
{ ${bar} = 123; }.foo  # 123
```

**Null attribute names are skipped**:

```nix
{ ${if foo then "bar" else null} = true; }
# Evaluates to {} if foo is false

**Functor pattern** - sets with `__functor` can be applied as functions:

```nix
let add = { __functor = self: x: x + self.x; };
    inc = add // { x = 1; };
in inc 1  # Evaluates to 2
```

#### Recursive Sets

Recursive sets allow attributes to refer to each other:

```nix
rec {
  x = y;
  y = 123;
}.x  # Evaluates to 123
```

> **Warning**: Recursive sets can cause infinite recursion:

```nix
rec {
  x = y;
  y = x;
}.x  # Crashes with "infinite recursion encountered"
```

---

### Names and Bindings

#### let-expressions

A let-expression allows you to define local variables for an expression:

```nix
let
  x = "foo";
  y = "bar";
in x + y  # "foobar"
```

#### Inheriting attributes

The `inherit` keyword copies variables from the surrounding lexical scope:

```nix
let x = 123; in
{
  inherit x;
  y = 456;
}
# Equivalent to: { x = x; y = 456; }
# Evaluates to: { x = 123; y = 456; }
```

Inherit from another attribute set:

```nix
inherit (src-set) a b c;
# Equivalent to: a = src-set.a; b = src-set.b; c = src-set.c;
```

In let expressions, `inherit` can selectively bring attributes into scope:

```nix
let
  x = { a = 1; b = 2; };
  inherit (builtins) attrNames;
in
{
  names = attrNames x;  # Can use attrNames directly
}
```

#### with-expressions

A *with-expression* introduces a set into the lexical scope:

```nix
let as = { x = "foo"; y = "bar"; };
in with as; x + y  # "foobar"
```

> **Note**: Use `with` sparingly - it can make code harder to read. Prefer `inherit` or explicit attribute access.

---

### Functions

Functions in Nix take exactly one argument. Multiple arguments are achieved through currying (nested functions).

```nix
# Single argument
x: x + 1

# Multiple arguments via currying
x: y: x + y

# Attribute set argument
{ a, b }: a + b

# Attribute set with defaults
{ a, b ? 0 }: a + b

# With additional attributes allowed (ellipsis)
{ a, b, ... }: a + b

# Named attribute set (@ pattern - access full argument)
args@{ a, b, ... }: a + b + args.c
```

**Set pattern with defaults**:

```nix
{ x, y ? "foo", z ? "bar" }: z + y + x
```

**@ pattern warning**: `args@` binds to the attribute set as passed, *not* including default values:

```nix
let
  f = args@{ a ? 23, ... }: [ a args ];
in
  f {}  # Evaluates to [ 23 {} ]
```

**Function parameters in scope**: All bindings introduced by the function are in scope in the entire function expression, including in default values:

```nix
let
  f = { x, y ? [x] }: { inherit y; };
in
  f { x = 3; }  # { y = [ 3 ]; }
```

---

### Control Flow

#### Conditionals

```nix
if e1 then e2 else e3
```

where *e1* must evaluate to a Boolean value (`true` or `false`).

#### Assertions

Assertions check that requirements hold:

```nix
assert e1; e2
```

If *e1* evaluates to `true`, *e2* is returned; otherwise evaluation is aborted and a backtrace is printed.

```nix
assert localServer -> db4 != null;
assert httpServer -> httpd != null && httpd.expat == expat;
```

> **Note**: `->` is the logical implication Boolean operation.

---

### Comments

- **Inline comments** start with `#` and run until the end of the line:

  ```nix
  # A number
  2 # Equals 1 + 1
  ```

- **Block comments** start with `/*` and run until the next `*/`:

  ```nix
  /*
    Block comments
    can span multiple lines.
  */ "hello"
  ```

  > **Note**: Block comments cannot be nested.

---

### Libraries

Two main libraries:

1. **`builtins`**: Primitive operations built into the language
   ```nix
   builtins.toString 1           # "1"
   builtins.fetchurl "https://..."
   builtins.elemAt [ "a" "b" ] 0 # "a"
   ```

2. **`pkgs.lib`** (or `lib` in modules): Nixpkgs library functions (implemented in Nix)
   ```nix
   lib.strings.toUpper "hello"
   lib.attrsets.mapAttrs (n: v: ...) {}
   ```

   When using `lib.*` functions, prefer `inherit` for cleaner code:
   ```nix
   let
     inherit (lib.strings) toUpper toLower;
   in
     toUpper "hello" + toLower "WORLD"
   ```

---

### Impurities

The only relevant impurity is reading files from the file system:

- **Paths in string interpolation**: `${./data}` copies file to Nix store
- **Fetchers**: `builtins.fetchurl`, `builtins.fetchTarball`, `builtins.fetchGit`

---

### Derivations

Derivations are the core of Nix - they describe build tasks:

```nix
derivation {
  name = "hello";
  builder = "/bin/sh";
  args = [ "-c" "echo $name > $out" ];
}
```

Usually wrapped by `stdenv.mkDerivation` in Nixpkgs.

---

## Module System

The module system enables:
- Declaring one attribute set using many separate Nix expressions
- Type constraints on values
- Defining values for the same attribute in different modules and merging automatically

### Basic Module Structure

```nix
{ lib, ... }:  # lib is automatically provided
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "The name";
    };
  };

  config = {
    name = "Boaty McBoatface";
  };
}
```

### Key Functions

- **`lib.mkOption`**: Declares options with types
- **`lib.evalModules`**: Evaluates a list of modules
- **`config`**: Where option values are defined
- **`imports`**: List of modules to include

### Option Types

Common types from `lib.types`:
- `str` - string
- `int` - integer
- `bool` - boolean
- `attrs` - attribute set
- `listOf type` - list of values of a type
- `submodule` - nested module

---

## Flakes

Flakes provide an entrypoint file `flake.nix` for sharing Nix code with a standard structure.

### Basic Flake Structure

```nix
{
  description = "My example flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux = {
      default = self.packages.x86_64-linux.hello;
      hello = nixpkgs.legacyPackages.x86_64-linux.hello;
    };
  };
}
```

### Key Features

- **`inputs`**: Declare dependencies with automatic locking in `flake.lock`
- **`outputs`**: The main function returning Nix values
- **Reproducible**: Defaults to pure mode (hermetic evaluation)
- **Git integration**: Only tracks staged files

### Running Flake Commands

```bash
# Enable flakes (if not enabled)
nix settings experimental-features = [ "nix-command" "flakes" ]

# Build
nix build .#packageName

# Run
nix run .#packageName

# From remote
nix run github:NixOS/nixpkgs#hello
```

### Dependency Management

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

Use `follows` to ensure shared dependencies.

### Pros and Cons

**Pros:**
- Easy reproducibility
- Cached builds
- Promotes declarative style

**Cons:**
- Experimental feature
- Can be slower for large repos (copies whole directory)
- No parameters (must be explicit about system)

---

## callPackage Pattern

`callPackage` is a convention in Nixpkgs for composing parameterized packages.

### Basic Usage

```nix
# hello.nix - package recipe
{ writeShellScriptBin }:
writeShellScriptBin "hello" ''
  echo "Hello, world!"
''

# default.nix
let
  pkgs = import <nixpkgs> {};
in
pkgs.callPackage ./hello.nix { }
```

### Parameterized Builds

```nix
# hello.nix with parameters
{
  writeShellScriptBin,
  audience ? "world",
}:
writeShellScriptBin "hello" ''
  echo "Hello, ${audience}!"
''

# Override at call time
pkgs.callPackage ./hello.nix { audience = "people"; }
```

### Overrides

```nix
rec {
  hello = pkgs.callPackage ./hello.nix { audience = "people"; };
  hello-folks = hello.override { audience = "folks"; };
}
```

### Interdependent Package Sets

```nix
let
  pkgs = import <nixpkgs> { };
  callPackage = pkgs.lib.callPackageWith (pkgs // packages);
  packages = rec {
    a = callPackage ./a.nix { };
    b = callPackage ./b.nix { inherit a; };
  };
in
packages
```

---

## Best Practices

### URLs
Always quote URLs: `"https://example.com"` instead of bare URLs.

### Recursive Attribute Sets
Avoid `rec`. Use `let ... in` instead:

```nix
# Bad
rec { a = 1; b = a + 2; }

# Good
let a = 1; in { a = a; b = a + 2; }
```

### With Scopes
Don't use `with` at the top of files:

```nix
# Bad
with (import <nixpkgs>{});

# Good
let pkgs = import <nixpkgs> {};
    inherit (pkgs) curl jq;
in
# ...
```

### Lookup Paths
Avoid `<nixpkgs>` in production. Pin dependencies explicitly.

### Nixpkgs Configuration
Always set config and overlays for reproducibility:

```nix
import <nixpkgs> { config = {}; overlays = []; }
```

### Nested Attribute Updates
Use `lib.recursiveUpdate` for deep merges:

```nix
lib.recursiveUpdate { a = { b = 1; }; } { a = { c = 3; }; }
# Result: { a = { b = 1; c = 3; }; }
```

### Reproducible Source Paths
Use `builtins.path` with fixed name:

```nix
src = builtins.path { path = ./.; name = "myproject"; };
```

### Prefer `inherit` Over `lib.*` or `builtins.*`
When writing Nix code, prefer the `inherit` paradigm instead of accessing functions via `lib.*` or `builtins.*` at each occurrence:

```nix
# Instead of:
result = lib.strings.toUpper "hello" + lib.strings.toLower "WORLD";

# Prefer:
let
  inherit (lib.strings) toUpper toLower;
in
  result = toUpper "hello" + toLower "WORLD";
```

---

## Shell Environments

### Ad Hoc Shells

```bash
# Create environment with packages
nix-shell -p cowsay lolcat

# Run single command
nix-shell -p git --run "git --version"

# Pure shell (isolated)
nix-shell -p git --pure
```

### Reproducible Environments

```bash
nix-shell -p git --run "git --version" \
  --pure \
  -I nixpkgs=https://github.com/NixOS/nixpkgs/tarball/COMMIT
```

---

## Pinning Nixpkgs

### Methods

1. **$NIX_PATH environment variable**
   ```bash
   NIX_PATH=nixpkgs=channel:nixos-22.11 nix-build
   ```

2. **-I option**
   ```bash
   nix-build -I nixpkgs=channel:nixos-22.11
   ```

3. **fetchTarball in Nix**
   ```nix
   let
     pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-22.11.tar.gz") {};
   in pkgs.stdenv.mkDerivation { ... }
   ```

### URL Patterns

- Local: `./path/to/expression.nix`
- Pinned commit: `https://github.com/NixOS/nixpkgs/archive/COMMIT.tar.gz`
- Channel: `channel:nixos-22.11`
- Latest release: `https://github.com/NixOS/nixpkgs/archive/release-22.11.tar.gz`

### Finding Commits

- [status.nixos.org](https://status.nixos.org/) - latest tested commits
- [nixos.org/channels](https://nixos.org/channels) - channel list

---

## Additional Resources

- [Nix Manual - Language](https://nix.dev/manual/nix/stable/language/index.html)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Pills](https://nixos.org/guides/nix-pills/) - detailed derivation explanation
