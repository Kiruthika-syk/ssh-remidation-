"""Jinja2 filters for Linux guest OS detection."""

from __future__ import annotations


def _is_linux_guest(vm: dict, patterns: list[str]) -> bool:
    name = (vm.get("guest_fullname") or "").lower()
    if not name:
        return False
    if "windows" in name or "microsoft" in name:
        return False
    return any(p.lower() in name for p in patterns)


def filter_linux_vms(vms: list, patterns: list[str]) -> list:
    return [vm for vm in vms if _is_linux_guest(vm, patterns)]


class FilterModule:
    def filters(self):
        return {"filter_linux_vms": filter_linux_vms}
