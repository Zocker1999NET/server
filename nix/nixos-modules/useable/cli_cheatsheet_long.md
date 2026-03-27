# CLI Tools Cheatsheet (Long Version)
<!--
To add a new tool to this cheatsheet:
1. Find the package in nixpkgs: nix eval nixpkgs#packageName.meta.description
2. Add the package to cli_cheatsheet_long.md with a 2-3 sentence description
  - if it provides multiple tools, list them accordingly
  - NOTE: When a package has that list, it means to NOT assume that it provides a tool with the same name.
    For example, dnsutils provides "dig" but NOT "dnsutils" itself.
3. Add the tool to cli_cheatsheet.md with a concise one-line description (max 80 chars)
4. Keep both files sorted alphabetically by tool name

Conversion rules:
- Long cheatsheet: Explains tools at package level. When a package provides multiple tools, list them in a "Tools provided:" section.
- Short cheatsheet: Explains at callable tool level. Each individual tool gets its own entry with a one-line description (max 80 chars).
- Sync rule: The content of both cheatsheets MUST stay in sync!
-->


### bandwhich
A cross-platform command-line utility that displays current network utilization by process, connection, and remote IP/hostname. It combines the functionality of tools like `netstat` and `iftop` into a single, intuitive interface with real-time updates and sorting capabilities.

### bat
A modern drop-in replacement for the classic `cat` command that adds syntax highlighting for over 200 programming languages and automatic Git integration. It displays file contents with beautiful syntax coloring, line numbers, and Git diff markers in the gutter, making it ideal for viewing code files in the terminal.

**Tools provided:**
- `bat`
- `batdiff`
- `batwatch`
- `prettybat`

### batmon
An interactive TUI (text-based user interface) application that displays battery status and health information in real-time. It shows charging state, current capacity, time remaining estimates, and battery health metrics with visual graphs and color-coded indicators.

### bmon
A portable bandwidth monitor and rate estimator that displays network traffic statistics in real-time. It supports multiple output modes including text, JSON, and XML, and can monitor multiple network interfaces simultaneously with per-interface bandwidth graphs.

### bluetuith
A terminal user interface (TUI) application for managing Bluetooth connections on Linux systems. It provides an interactive interface for pairing, connecting, and managing Bluetooth devices without needing graphical tools, supporting both classic Bluetooth and BLE devices.

### csvkit
A suite of command-line utilities for working with CSV files, providing tools to convert between formats, filter, aggregate, and analyze tabular data. It includes utilities like `csvcut`, `csvgrep`, `csvsort`, and `csvstat` for common data manipulation tasks.

**Tools provided:**
- `csvcut`
- `csvgrep`
- `csvsort`
- `csvstat`

### dnsutils
Its most important utility is `dig` allowing to query for specific DNS records.

**Tools provided:**
- `dig`

### ethtool
A utility for querying and controlling network driver and hardware settings for Ethernet devices. It can display device information, set speed/duplex/autonegotiation, enable wake-on-LAN, and perform hardware diagnostics.

### fzf
A general-purpose command-line fuzzy finder written in Go that allows for interactive filtering and selection of items from any list. It features fuzzy matching algorithm, preview window support, and can be integrated with various command-line tools for enhanced searching capabilities.

### intel-gpu-tools
A collection of tools for development, testing, and debugging of the Intel DRM (Direct Rendering Manager) driver and GPU hardware. It includes utilities for performance analysis, hardware state inspection, and debugging graphics issues on Intel integrated and discrete GPUs.

### iotop
A terminal-based tool that displays input/output usage by processes, similar to how `top` shows CPU usage. It helps identify which processes are performing the most disk I/O operations, with real-time updates and the ability to filter for specific processes.

### jq
A lightweight and flexible command-line JSON processor that allows for parsing, filtering, transforming, and extracting data from JSON documents. It uses a powerful expression syntax for complex data manipulation and is commonly used in shell scripts for JSON API responses.

### liboping
A C library that generates ICMP echo request packets (ping packets) and measures round-trip times to multiple hosts simultaneously. Unlike traditional ping, it can handle multiple targets in parallel and transparently supports both IPv4 and IPv6. It provides a programmatic interface for network latency measurement and includes command-line tools built on the library.

**Tools provided:**
- `oping`
- `noping`

### manix
A fast command-line documentation searcher for Nix and NixOS that provides instant search results across all available man pages and option documentation. It queries local nixpkgs documentation and displays results with syntax highlighting and quick navigation.

### massren
A command-line tool that makes it easy to rename multiple files using your preferred text editor. It opens all selected filenames in an editor, allowing for batch renaming through familiar editing commands, with undo support.

### mtr
A network diagnostic tool that combines the functionality of `ping` and `traceroute` into a single continuous display. It shows the route path to a destination along with packet loss and latency statistics for each hop in real-time.

### nethogs
A small network monitoring tool that groups bandwidth usage by process, showing which applications are consuming the most network bandwidth. Unlike traditional network monitors that show per-interface statistics, it attributes traffic to specific processes.

### nvtop
A ncurses-based GPU monitoring tool similar to htop but for GPUs, providing real-time visualization of GPU utilization, memory usage, and temperature for AMD, Intel, and NVIDIA graphics cards. It displays a curses-based interface with per-process GPU usage, fan speed, and power consumption metrics in an intuitive, color-coded format.

### psitop
A top-like utility that displays real-time pressure stall information from the Linux kernel's /proc/pressure interface. It shows CPU, memory, and I/O pressure metrics that indicate how much contention exists for system resources.

### psmisc
A collection of small utilities that use the Linux proc filesystem (/proc), including `pstree` for process trees, `fuser` to identify processes using files, `killall` to signal processes by name, and `pextract` for process extraction.

**Tools provided:**
- `fuser`
- `killall`
- `pextract`
- `pstree`

### pv
A terminal utility that monitors the progress of data through a pipeline, displaying throughput statistics and a progress bar. It can be inserted into any pipeline to visualize data flow rate, estimated time remaining, and current position.

### reptyr
A tool that allows reparenting a running program to a new terminal, effectively moving a process from one terminal to another without interrupting its execution. This is useful for attaching to long-running processes that were started in a different terminal.

### smem
A memory usage reporting tool that provides reports on memory consumption with a focus on shared memory calculations. Unlike standard memory reporters, it accurately accounts for shared library memory that is counted multiple times in other tools.

### speedtest-cli
A command-line interface for testing internet bandwidth using the speedtest.net network. It performs download and upload speed tests without requiring a web browser, making it useful for automated testing and server environments.

### up
The Ultimate Plumber is a Linux tool for writing and testing data pipelines with instant live preview of each stage's output. It provides an interactive editing environment where you can modify pipeline commands and see results immediately without executing the full pipeline.

### usbtop
A top-like utility that displays estimated instantaneous bandwidth usage on USB buses and connected devices. It helps identify which USB devices are consuming the most bandwidth in real-time.


## Frontend ZSH Plugins (Frontend Systems Only)
This section documents zsh plugins available on frontend systems with home-manager configured.

### autojump
A shell utility that enables quick navigation to previously visited directories using a weighted directory database. It tracks directory frequency and recency to offer the most likely target when typing `j`, making it faster than `cd` for frequently used folders.

**Tools provided:**
- `autojump --stat` (show statistics)
- `j` (jump to directory)
- `jc` (jump to child directory)
- `jo` (open file manager in directory)

### bofh
A BOFH (Bastard Operator From Hell) fortune plugin that displays random excuses and tech humor. Useful for entertainment or as a fun MOTD.

**Tools provided:**
- `bofh`
- `bofh_cow`

### dirhistory
A zsh plugin that adds keyboard shortcuts for navigating directory history and hierarchy. It maintains a stack of previously visited directories (max 30) and allows quick navigation using Alt+Arrow keys. Also provides the `cde` alias for changing directories without clearing the future stack.

**Tools provided:**
- `cde` (change directory without clearing stack)
- `Alt+Left` (go to previous directory)
- `Alt+Right` (go to next directory)
- `Alt+Up` (move to parent directory)
- `Alt+Down` (move into first child directory)

### zpm-zsh/clipboard
Cross-platform clipboard integration for zsh that works on macOS, X11, Wayland, Cygwin, and WSL. Provides familiar clipboard commands.

**Tools provided:**
- `pbcopy`
- `pbpaste`
- `clip`

### zsh-auto-notify
Sends desktop notifications when long-running commands complete, so you can switch to other tasks while waiting for builds or downloads to finish.

**Tools provided:**
- `disable_auto_notify`
- `enable_auto_notify`

### zsh-autoquoter
Automatically adds quotes around arguments to certain commands like git commit and ssh. This saves time manually escaping quotes in complex command-line arguments.

**Tools provided:**
- `git commit -m` (auto-quoted prefix)
- `ssh *` (auto-quoted prefix)

### zsh-change-case
A zle widget that changes the case of words in the command line, similar to VSCode and Sublime Text. Useful for quick case transformations.

**Tools provided:**
- `Ctrl+K+U` (UPPERCASE)
- `Ctrl+K+L` (lowercase)

### zsh-delete-prompt
Deletes prompt text from the current line, useful when pasting commands from the web or README files. It detects leading non-alphanumeric characters as a prompt and removes them.

**Tools provided:**
- `Alt+d` (keybinding)

### zsh-gtr
Git Tag Release - creates signed git release tags with automatic versioning and pushing. The tag format is release-YYYY-MM-DD-HH-MM with an editable message.

**Tools provided:**
- `gtr`
