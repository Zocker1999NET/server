#!/usr/bin/env python3

from __future__ import annotations

import argparse
import logging
from pathlib import Path

from .action_lib import (
    StateSyncer,
)
from .config import (
    build_actions,
    build_ip_sources,
    read_config,
)
from .config.types import (
    LoggingConfig,
)
from .extras.ntfy_log import (
    NtfyHandler,
)
from .state_lib import (
    CachedSource,
    FileStateManager,
)

logging.root.setLevel(logging.NOTSET)
logger = logging.getLogger(__name__)
# configure local logging
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
logger.addHandler(console_handler)


# app


STATE_KEY_CURRENT_IPS = "current_ips"
"state key prefix of per-action applied IP sets"
STATE_KEY_DISCOVERED_IPS = "discovered_ips"
"state key of the cached discovered IP set"


def main() -> None:
    "builds the pipeline from config and synchronizes every configured action"
    args = __parse_args()
    logger.info("read config")
    config = read_config(args.config)
    configure_logging(config.logging)
    logger.info("plug together pipeline from config")
    state_mgr = FileStateManager[str, list[str]](
        paths=(Path(args.state_dir),),
    )
    state_mgr.load_states()

    logger.info("build IP discovery pipeline, wrapped in a persistent cache")
    ip_cache = state_mgr.for_key(STATE_KEY_DISCOVERED_IPS)
    ip_src = CachedSource(
        source=build_ip_sources(config),
        state=ip_cache,
    )

    logger.info("build update actions from config")
    actions = build_actions(config)
    if not actions:
        logger.warning("no actions configured; nothing to sync")
        state_mgr.store_states()
        return

    for idx, action in enumerate(actions):
        target_state = state_mgr.for_key(f"{STATE_KEY_CURRENT_IPS}:{idx}")
        syncer = StateSyncer(
            action=action,
            source_state=ip_src,
            target_state=target_state,
        )
        logger.info("syncing action %s/%s", idx + 1, len(actions))
        result = syncer.attempt_sync()
        if result.process_error:
            logger.error("sync failed: %s", syncer.last_error)
        else:
            logger.info("sync result: %s", result.name)

    state_mgr.store_states()


def __parse_args() -> argparse.Namespace:
    "parses CLI arguments"
    parser = argparse.ArgumentParser(
        prog="dns-dynamic-primary-reflector",
        description="keeps Hetzner DNS primary nameservers in sync with dynamic public IPs",
    )
    parser.add_argument(
        "--config",
        default="./example_config.json",
        help="path of the JSON config file",
    )
    parser.add_argument(
        "--state-dir",
        default="./ip_updates_states",
        help="path of the state file",
    )
    return parser.parse_args()


def configure_logging(config: LoggingConfig) -> None:
    "adds a remote ntfy logging handler if configured"
    # configure remote logging
    ntfy_config = config.ntfy
    if ntfy_config is not None:
        logger.info("setup ntfy remote logger for %s", ntfy_config.url)
        ntfy_handler = NtfyHandler(ntfy_config.url)
        ntfy_handler.setLevel(logging.WARNING)
        logger.addHandler(ntfy_handler)


if __name__ == "__main__":
    main()
