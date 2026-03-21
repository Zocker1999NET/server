#!/usr/bin/env python3
"""
builderctl - Interact with autoPush and autoUpdate services.

It provides an easy way to interact with a server that has autoPush
and autoUpdate installed.
"""

import subprocess
import sys
import argparse
from pathlib import Path

# =============================================================================
# HARDCODED SERVER SETTINGS
# =============================================================================
SERVER_HOST = "fde3:b424:b5ce:1:be24:11ff:feb5:580c"  # nix-builder.boreth.pve.6nw.de
SERVER_USER = "root"
REPO_REMOTE = "git@github.com:Zocker1999NET/server"
REPO_LOCAL = Path.cwd()
STAGING_BRANCH = "staging"
MAIN_BRANCH = "main"
AUTO_UPDATED_REMOTE = "nix-builder"
AUTO_UPDATED_BRANCH = "autoUpdated"

# Service names on the remote server
SERVICE_AUTO_PUSH = "srv-autoPush"
SERVICE_AUTO_UPDATE = "srv-autoUpdate"
# =============================================================================


# =============================================================================
# REMOTE COMMAND EXECUTION HELPERS
# =============================================================================


def run_remote_command(
    cmd: str, capture_output: bool = False, check: bool = True
) -> subprocess.CompletedProcess:
    """Execute a command on the remote server via SSH."""
    ssh_cmd = ["ssh", f"{SERVER_USER}@{SERVER_HOST}", cmd]
    result = subprocess.run(
        ssh_cmd, check=check, capture_output=capture_output, text=True
    )
    return result


def run_remote_command_follow(cmd: str) -> int:
    """Execute a command on the remote server via SSH with pseudo-terminal for interactive output."""
    ssh_cmd = ["ssh", "-t", f"{SERVER_USER}@{SERVER_HOST}", cmd]
    try:
        result = subprocess.run(ssh_cmd, check=True, text=True)
        return result.returncode
    except subprocess.CalledProcessError as e:
        return e.returncode
    except KeyboardInterrupt:
        return 0


def get_service_status(service: str) -> None:
    """Get and print the status of a systemd service on the remote server."""
    cmd = f"systemctl status {service}.service --no-pager"
    try:
        # Note: systemctl returns exit code 3 if service is inactive, so we don't check exit code
        result = run_remote_command(cmd, capture_output=True, check=False)
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
    except subprocess.SubprocessError as e:
        print(f"Error getting status for {service}: {e}", file=sys.stderr)


def get_services_status(services: list[str]) -> None:
    """Get and print the status of multiple systemd services on the remote server."""
    # Pass each service as a separate argument to systemctl
    # Note: systemctl returns exit code 3 if any service is inactive, so we don't check exit code
    cmd = "systemctl status --no-pager " + " ".join(f"{s}.service" for s in services)
    try:
        result = run_remote_command(cmd, capture_output=True, check=False)
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
    except subprocess.SubprocessError as e:
        print(f"Error getting status for services: {e}", file=sys.stderr)


def start_service_follow(service: str) -> int:
    """Start a systemd service on the remote server and follow its journal logs."""
    cmd = f"systemctl start {service}.service && journalctl --follow --unit={service}.service"
    return run_remote_command_follow(cmd)


def get_service_name(service_type: str) -> str:
    """Get the actual service name for a given service type."""
    if service_type == "autoPush":
        return SERVICE_AUTO_PUSH
    elif service_type == "autoUpdate":
        return SERVICE_AUTO_UPDATE
    else:
        raise ValueError(f"Unknown service type: {service_type}")


def run_command(
    cmd: list[str], check: bool = True, capture_output: bool = False
) -> subprocess.CompletedProcess:
    """Run a shell command locally and return the result."""
    result = subprocess.run(cmd, check=check, capture_output=capture_output, text=True)
    return result


# =============================================================================
# GIT HELPER FUNCTIONS
# =============================================================================


def check_git_clean() -> bool:
    """Check if the git working directory is clean (no uncommitted changes)."""
    result = run_command(
        ["git", "status", "--untracked-files=no", "--porcelain"],
        check=True,
        capture_output=True,
    )
    return result.stdout.strip() == ""


# =============================================================================
# autoUpdate COMMANDS
# =============================================================================


def autoUpdate_pull() -> int:
    """
    Pull autoUpdate from the server.

    This replicates the functionality of pull_autoUpdate.sh:
    1. Check that working directory is clean
    2. Switch to staging branch
    3. Pull latest changes
    4. Fetch from nix-builder remote
    5. Merge nix-builder/autoUpdated branch (ff-only)
    6. Run nix flake archive
    7. Rebase with amended commits (for GPG signing)
    8. Push to remote
    """
    # Step 1: Check working directory is clean
    if not check_git_clean():
        print(
            "ERROR: Working directory must be clean for pulling autoUpdate!",
            file=sys.stderr,
        )
        return 1

    # Step 2: Switch to staging branch
    run_command(["git", "switch", STAGING_BRANCH])

    # Step 3: Pull latest changes
    run_command(["git", "pull"])

    # Step 4: Fetch from nix-builder remote
    run_command(["git", "fetch", AUTO_UPDATED_REMOTE])

    # Step 5: Merge nix-builder/autoUpdated branch (ff-only)
    run_command(
        ["git", "merge", "--ff-only", f"{AUTO_UPDATED_REMOTE}/{AUTO_UPDATED_BRANCH}"]
    )

    # Step 6: Run nix flake archive
    run_command(["nix", "flake", "archive"])

    # Step 7: Rebase with amended commits (for GPG signing)
    run_command(
        [
            "git",
            "rebase",
            "--exec",
            f"git commit --amend --no-edit",
            f"origin/{STAGING_BRANCH}",
        ]
    )

    # Step 8: Push to remote
    run_command(["git", "push"])

    return 0


def autoUpdate_trigger() -> int:
    """
    Trigger autoUpdate on the server.

    Starts the autoUpdate service on the remote server.
    """
    return start_service_follow(get_service_name("autoUpdate"))


def autoUpdate_status() -> int:
    """Check the status of the autoUpdate service on the server."""
    get_service_status(get_service_name("autoUpdate"))
    return 0


# =============================================================================
# autoPush COMMANDS
# =============================================================================


def autoPush_trigger() -> int:
    """
    Trigger autoPush on the server.

    This replicates the functionality of trigger_autoPush.sh:
    1. If on staging branch, push local changes
    2. SSH to server and start autoPush.service
    3. Follow the journal logs
    """
    # Step 1: Check current branch and push if on staging
    result = run_command(
        ["git", "branch", "--show-current"], check=True, capture_output=True
    )
    current_branch = result.stdout.strip()

    if current_branch == STAGING_BRANCH:
        run_command(["git", "push"])

    # Step 2: SSH to server and start autoPush.service
    return start_service_follow(get_service_name("autoPush"))


def autoPush_status() -> int:
    """Check the status of the autoPush service on the server."""
    get_service_status(get_service_name("autoPush"))
    return 0


# =============================================================================
# GLOBAL COMMANDS
# =============================================================================


def status_all() -> int:
    """Check the status of autoPush and autoUpdate services on the server."""
    get_services_status([SERVICE_AUTO_PUSH, SERVICE_AUTO_UPDATE])
    return 0


def show_config() -> int:
    """Display the current configuration."""
    print(f"Server Host:       {SERVER_HOST}")
    print(f"Server User:       {SERVER_USER}")
    print(f"Repo Remote:       {REPO_REMOTE}")
    print(f"Staging Branch:    {STAGING_BRANCH}")
    print(f"Main Branch:       {MAIN_BRANCH}")
    print(f"autoUpdate Remote: {AUTO_UPDATED_REMOTE}")
    print(f"autoUpdate Branch: {AUTO_UPDATED_BRANCH}")
    return 0


# =============================================================================
# MAIN & ARGUMENT PARSING
# =============================================================================


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Interact with autoPush and autoUpdate services on the server.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # autoUpdate subcommands
    autoUpdate_parser = subparsers.add_parser(
        "autoUpdate", help="autoUpdate service commands"
    )
    autoUpdate_subparsers = autoUpdate_parser.add_subparsers(dest="subcommand")
    autoUpdate_subparsers.add_parser("pull", help="Pull autoUpdate from server")
    autoUpdate_subparsers.add_parser(
        "trigger", help="Trigger autoUpdate service on server"
    )
    autoUpdate_subparsers.add_parser(
        "status", help="Check status of autoUpdate service"
    )

    # autoPush subcommands
    autoPush_parser = subparsers.add_parser(
        "autoPush", help="autoPush service commands"
    )
    autoPush_subparsers = autoPush_parser.add_subparsers(dest="subcommand")
    autoPush_subparsers.add_parser("trigger", help="Trigger autoPush service on server")
    autoPush_subparsers.add_parser("status", help="Check status of autoPush service")

    # Global commands
    subparsers.add_parser(
        "status", help="Check status of autoPush and autoUpdate services"
    )
    subparsers.add_parser("config", help="Show current configuration")

    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        return 1

    if args.command == "autoUpdate":
        if args.subcommand == "pull":
            return autoUpdate_pull()
        elif args.subcommand == "trigger":
            return autoUpdate_trigger()
        elif args.subcommand == "status":
            return autoUpdate_status()
        else:
            autoUpdate_parser.print_help()
            return 1
    elif args.command == "autoPush":
        if args.subcommand == "trigger":
            return autoPush_trigger()
        elif args.subcommand == "status":
            return autoPush_status()
        else:
            autoPush_parser.print_help()
            return 1
    elif args.command == "status":
        return status_all()
    elif args.command == "config":
        return show_config()
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
