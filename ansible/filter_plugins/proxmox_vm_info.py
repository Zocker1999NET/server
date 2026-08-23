__metaclass__ = type

DOCUMENTATION = r"""
  name: normalize_proxmox_vms
  author: Zocker1999NET
  short_description: Normalize proxmox_vm_info return data for easier use
  description:
    - Adapts the structure of the C(proxmox_vms) list returned by
      M(community.proxmox.proxmox_vm_info) so it is easier to work with in
      playbooks.
    - For every VM object it ensures the keys C(status), C(name), C(vmid) and
      C(node) are defined and raises an error otherwise.
    - Adds a C(desc_name) key to each VM object, which is a string of the form
      C(<vmid> (<name>)).
    - Splits the semicolon-separated C(tags) string of each VM into a list of
      tags, defaulting to an empty list when the C(tags) key is absent.
  options:
    vms:
      description:
        - The C(proxmox_vms) list returned by the proxmox_vm_info module.
      type: list
      required: true
"""

from ansible.errors import AnsibleFilterError, AnsibleUndefinedVariable
from ansible.module_utils.common.text.converters import to_native
from ansible.template import AnsibleUndefined

from jinja2.exceptions import UndefinedError

# Keys that every VM object returned by proxmox_vm_info must define.
REQUIRED_KEYS = ("status", "name", "vmid", "node")


def _is_defined(value):
    """Return whether a value is defined (not an AnsibleUndefined)."""
    return not isinstance(value, AnsibleUndefined)


def _split_tags(tags, vmid):
    """Turn the semicolon-separated tags string into a list of tags."""
    if tags is None or isinstance(tags, AnsibleUndefined):
        return []
    if isinstance(tags, str):
        # An empty (or stray-semicolon) string must yield no tags, not [""].
        return [tag for tag in tags.split(";") if tag != ""]
    if isinstance(tags, list):
        # Already a list (e.g. from another source); pass through defensively.
        return list(tags)
    raise AnsibleFilterError(
        f"proxmox VM {vmid}: unsupported 'tags' type {type(tags).__name__} (expected str or list)"
    )


def _normalize_vm(vm, index):
    if not isinstance(vm, dict):
        raise AnsibleFilterError(
            f"proxmox_vm_info entry #{index} is not a dict: {vm!r}"
        )

    vmid = vm.get("vmid", index)
    missing = [
        key for key in REQUIRED_KEYS if key not in vm or not _is_defined(vm[key])
    ]
    if missing:
        raise AnsibleFilterError(
            f"proxmox VM {vmid} is missing required key(s): {', '.join(missing)}"
        )

    normalized = dict(vm)
    normalized["desc_name"] = f"{vm['vmid']} ({vm['name']})"
    normalized["tags"] = _split_tags(vm.get("tags"), vmid)
    return normalized


def normalize_proxmox_vms(vms):
    try:
        if isinstance(vms, AnsibleUndefined):
            raise UndefinedError(to_native(vms))
        if not isinstance(vms, list):
            raise AnsibleFilterError(
                f"normalize_proxmox_vms expects a list, got {type(vms).__name__}"
            )
        return [_normalize_vm(vm, i) for i, vm in enumerate(vms)]
    except UndefinedError as e:
        raise AnsibleUndefinedVariable(f"normalize_proxmox_vms: {to_native(e)}")
    except AnsibleFilterError:
        raise
    except Exception as e:
        raise AnsibleFilterError(f"normalize_proxmox_vms: {to_native(e)}")


class FilterModule(object):
    """Ansible filter plugin for proxmox_vm_info data."""

    def filters(self):
        return {
            "normalize_proxmox_vms": normalize_proxmox_vms,
        }
