#!/usr/bin/env python3
# mypy: disallow_untyped_defs, disallow_incomplete_defs, disallow_untyped_calls, disallow_untyped_decorators, warn_return_any, warn_unreachable, warn_unused_ignores, no_implicit_optional
"""
builderctl - Interact with autoPush and autoUpdate services.

It provides an easy way to interact with a server that has autoPush
and autoUpdate installed.
"""

import argparse
import shlex
import subprocess
import sys
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any, Callable, Optional, Protocol

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
# =============================================================================


# =============================================================================
# REMOTE COMMAND EXECUTION HELPERS
# =============================================================================


def run_remote_command(
    *cmd: str,
    ssh_args: tuple[str, ...] = (),
    capture_output: bool = False,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    """Execute a command on the remote server via SSH."""
    # Use shlex.join to properly quote and join arguments
    cmd_str = shlex.join(cmd)
    ssh_cmd = ["ssh", *ssh_args, f"{SERVER_USER}@{SERVER_HOST}", cmd_str]
    result = subprocess.run(
        ssh_cmd, check=check, capture_output=capture_output, text=True
    )
    return result


def run_remote_command_follow(*cmd: str) -> subprocess.CompletedProcess[str]:
    """Execute a command on the remote server via SSH with pseudo-terminal for interactive output."""
    try:
        return run_remote_command(*cmd, ssh_args=("-t",), check=True)
    except subprocess.CalledProcessError:
        # Re-raise CalledProcessError so caller can handle it
        raise
    except KeyboardInterrupt:
        # Return a dummy result for KeyboardInterrupt
        # Create a minimal CompletedProcess to satisfy return type
        return subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")


def get_service_status(service: str) -> None:
    """Get and print the status of a systemd service on the remote server."""
    try:
        # Note: systemctl returns exit code 3 if service is inactive, so we don't check exit code
        result = run_remote_command(
            "systemctl", "status", f"{service}.service", "--no-pager",
            capture_output=True, check=False
        )
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
    except subprocess.SubprocessError as e:
        print(f"Error getting status for {service}: {e}", file=sys.stderr)


def get_services_status(services: list[str]) -> None:
    """Get and print the status of multiple systemd services on the remote server."""
    # Pass each service as a separate argument to systemctl
    # Note: systemctl returns exit code 3 if any service is inactive, so we don't check exit code
    try:
        cmd_args = ["systemctl", "status", "--no-pager"] + [f"{s}.service" for s in services]
        result = run_remote_command(*cmd_args, capture_output=True, check=False)
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
    except subprocess.SubprocessError as e:
        print(f"Error getting status for services: {e}", file=sys.stderr)


def start_service_follow(service: str) -> int:
    """Start a systemd service on the remote server and follow its journal logs."""
    # Run commands sequentially, not chained with &&
    run_remote_command("systemctl", "start", f"{service}.service")
    result = run_remote_command_follow("journalctl", "--follow", f"--unit={service}.service")
    return result.returncode


def get_service_last_start_time(service: str) -> str:
    """Get the last start time of a systemd service on the remote server."""
    result = run_remote_command(
        "systemctl", "show", f"{service}.service",
        "--property=ActiveEnterTimestamp", "--value",
        capture_output=True, check=True
    )
    return result.stdout.strip()


def journal_service(service: str, follow: bool = False) -> int:
    """
    Show journal logs for a systemd service starting from its last start time.

    Args:
        service: The service name (e.g., "srv-autoPush" or "srv-autoUpdate")
        follow: Whether to follow the journal (like tail -f)
    """
    last_start = get_service_last_start_time(service)

    if not last_start:
        print(f"Error: Could not determine last start time for {service}", file=sys.stderr)
        return 1

    cmd_args = [
        "journalctl",
        f"--unit={service}.service",
        f"--since={last_start}",
    ]
    if follow:
        cmd_args.append("--follow")

    print(f"Showing logs since: {last_start}")
    print(f"Command: {shlex.join(cmd_args)}")
    print("---")

    result = run_remote_command_follow(*cmd_args)
    return result.returncode


def run_command(
    *cmd: str, check: bool = True, capture_output: bool = False
) -> subprocess.CompletedProcess[str]:
    """Run a shell command locally and return the result."""
    result = subprocess.run(cmd, check=check, capture_output=capture_output, text=True)
    return result


def run_commands(
    *cmds: tuple[str, ...], check: bool = True, capture_output: bool = False
) -> list[subprocess.CompletedProcess[str]]:
    """Run multiple shell commands sequentially and return all results."""
    results: list[subprocess.CompletedProcess[str]] = []
    for cmd in cmds:
        result = run_command(*cmd, check=check, capture_output=capture_output)
        results.append(result)
    return results


# =============================================================================
# GIT HELPER FUNCTIONS
# =============================================================================


def check_git_clean() -> bool:
    """Check if the git working directory is clean (no uncommitted changes)."""
    result = run_command(
        "git", "status", "--untracked-files=no", "--porcelain",
        check=True,
        capture_output=True,
    )
    return result.stdout.strip() == ""


# =============================================================================
# GLOBAL COMMANDS
# =============================================================================


def status_all() -> int:
    """Check the status of autoPush and autoUpdate services on the server."""
    get_services_status(["srv-autoPush", "srv-autoUpdate"])
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
# SERVICE DEFINITIONS
# =============================================================================


class CommandHandler(Protocol):
    """Protocol defining the interface for command handlers."""

    def __call__(self) -> int:
        """Execute the command and return exit code."""
        ...


class SubparsersAction(Protocol):
    """Protocol defining the interface for subparser actions."""

    def add_parser(self, name: str, **kwargs: Any) -> argparse.ArgumentParser:
        ...


class ServiceDefinition(ABC):
    """Abstract base class for all services."""

    name: str = ""
    systemd_name: str = ""
    help: str = ""

    def _add_command(
        self,
        subparsers: SubparsersAction,
        cmd_name: str,
        cmd_help: str,
        handler: CommandHandler,
    ) -> argparse.ArgumentParser:
        """Add a command subparser and attach its handler to the namespace."""
        cmd_parser = subparsers.add_parser(cmd_name, help=cmd_help)
        cmd_parser.set_defaults(**{f"{self.name}_handler": handler})
        return cmd_parser

    def _add_commands(self, subparsers: SubparsersAction) -> None:
        """
        Add the base commands (trigger, status, journal) to the subparsers.
        Override in subclasses to add more commands.
        """
        self._add_command(subparsers, "trigger", "Trigger the service", self.trigger)
        self._add_command(subparsers, "status", "Show service status", self.status)
        self._add_command(subparsers, "journal", "Show service journal", self.journal)

    def create_subparser(self, subparsers: SubparsersAction) -> None:
        """Create the subparser for this service."""
        parser = subparsers.add_parser(self.name, help=self.help)
        sub = parser.add_subparsers(dest=f"{self.name}_subcommand")
        self._add_commands(sub)

    @abstractmethod
    def trigger(self) -> int:
        """Trigger the service to run."""
        pass

    def status(self) -> int:
        """Show the status of the service."""
        get_service_status(self.systemd_name)
        return 0

    def journal(self) -> int:
        """Show the journal of the service."""
        return journal_service(self.systemd_name)


class AutoPushService(ServiceDefinition):
    """Service for pushing NixOS configurations and triggering builds."""

    name = "autoPush"
    systemd_name = "srv-autoPush"
    help = "autoPush service commands"

    # Uses base class create_subparser and _add_commands (trigger, status, journal)

    def trigger(self) -> int:
        result = run_command(
            "git", "branch", "--show-current", check=True, capture_output=True
        )
        branch = result.stdout.strip()
        if branch == STAGING_BRANCH:
            run_command("git", "push")
        return start_service_follow(self.systemd_name)


class AutoUpdateService(ServiceDefinition):
    """Service for pulling updated configurations after builds."""

    name = "autoUpdate"
    systemd_name = "srv-autoUpdate"
    help = "autoUpdate service commands"

    def _add_commands(self, subparsers: SubparsersAction) -> None:
        """Add commands: pull + base commands (trigger, status, journal)."""
        self._add_command(subparsers, "pull", "Pull autoUpdate from server", self.pull)
        super()._add_commands(subparsers)

    def pull(self) -> int:
        """
        Pull autoUpdate from the server.

        This replicates the functionality of the former pull_autoUpdate.sh.
        """
        if not check_git_clean():
            print(
                "ERROR: Working directory must be clean for pulling autoUpdate!",
                file=sys.stderr,
            )
            return 1

        run_commands(
            ("git", "switch", STAGING_BRANCH),
            ("git", "pull"),
            ("git", "fetch", AUTO_UPDATED_REMOTE),
            ("git", "merge", "--ff-only", f"{AUTO_UPDATED_REMOTE}/{AUTO_UPDATED_BRANCH}"),
            ("nix", "flake", "archive"),
            (
                "git",
                "rebase",
                "--exec",
                "git commit --amend --no-edit",
                f"origin/{STAGING_BRANCH}",
            ),
            ("git", "push"),
        )
        return 0

    def trigger(self) -> int:
        """Trigger autoUpdate on the server."""
        return start_service_follow(self.systemd_name)

    def status(self) -> int:
        """Check status of autoUpdate service."""
        get_service_status(self.systemd_name)
        return 0

    def journal(self) -> int:
        """Show journal logs for autoUpdate service."""
        return journal_service(self.systemd_name)


# =============================================================================
# SERVICE REGISTRY
# =============================================================================


class ServiceRegistry:
    """Registry for managing services and dispatching commands."""

    def __init__(self) -> None:
        self._services: dict[str, ServiceDefinition] = {}

    def register(self, service: ServiceDefinition) -> None:
        self._services[service.name] = service

    def get(self, name: str) -> Optional[ServiceDefinition]:
        return self._services.get(name)

    def create_parser(self) -> argparse.ArgumentParser:
        parser = argparse.ArgumentParser(
            prog="builderctl",
            description="Control builder services on the remote NixOS builder",
        )
        subparsers = parser.add_subparsers(dest="command", help="Available commands")

        # Register service subparsers
        for svc in self._services.values():
            svc.create_subparser(subparsers)

        # Add global commands
        subparsers.add_parser("status", help="Check status of all services")
        subparsers.add_parser("config", help="Show current configuration")

        return parser

    def dispatch(self, args: argparse.Namespace) -> int:
        # Global commands
        if args.command == "status":
            return status_all()
        elif args.command == "config":
            return show_config()

        # Service-specific - handler already attached to namespace via set_defaults
        handler: Optional[CommandHandler] = getattr(args, f"{args.command}_handler", None)
        if handler is not None:
            return handler()
        return 1


# =============================================================================
# MAIN
# =============================================================================


def main() -> int:
    registry = ServiceRegistry()
    registry.register(AutoPushService())
    registry.register(AutoUpdateService())

    parser = registry.create_parser()
    args = parser.parse_args()

    if not hasattr(args, 'command') or args.command is None:
        parser.print_help()
        return 1

    return registry.dispatch(args)


if __name__ == "__main__":
    sys.exit(main())
