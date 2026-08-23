__metaclass__ = type

DOCUMENTATION = r"""
  name: ordered_intersect
  author: Zocker1999NET
  short_description: Intersection that preserves the order of the first list
  description:
    - Returns the elements of the first list that are also present in the
      second list, keeping the order and duplicates of the first list.
    - Unlike the built-in C(intersect) filter, the result order is not
      arbitrary but follows the first list.
    - Elements must be hashable.
  options:
    list1:
      description:
        - The list whose order and duplicates are preserved.
      type: list
      required: true
    list2:
      description:
        - The list to test membership against.
      type: list
      required: true
"""

from ansible.errors import AnsibleFilterError
from ansible.module_utils.common.text.converters import to_native


def ordered_intersect(list1, list2):
    if not isinstance(list1, list):
        raise AnsibleFilterError(
            f"ordered_intersect expects a list as first argument, got {type(list1).__name__}"
        )
    if not isinstance(list2, list):
        raise AnsibleFilterError(
            f"ordered_intersect expects a list as second argument, got {type(list2).__name__}"
        )
    try:
        allowed = set(list2)
        return [item for item in list1 if item in allowed]
    except Exception as e:
        raise AnsibleFilterError(f"ordered_intersect: {to_native(e)}")


class FilterModule(object):
    """Ansible filter plugin providing an order-preserving intersection."""

    def filters(self):
        return {
            "ordered_intersect": ordered_intersect,
        }
