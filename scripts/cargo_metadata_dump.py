#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import json
from utils import run_cmd


def resolve_targets(device: str) -> Tuple[str, str]:
    # 'cargo metadata' exposes the per-device sections of '[package.metadata.ledger]'
    # under the Rust target name, while the rest of the toolchain (and the emitted
    # manifest) uses the C target name. They only differ for Nano S+.
    if device == "nanosp":
        return "nanosplus", "nanos2"
    return device, device


def device_icon(section: Dict, rust_target: str) -> Optional[str]:
    # A '[package.metadata.ledger]' (or per-variant) table carries a per-device
    # sub-table holding the 'icon' entry, e.g. 'nanox = { icon = "..." }'.
    target_metadata = section.get(rust_target)
    if isinstance(target_metadata, dict):
        return target_metadata.get("icon")
    return None


def format_app_flags(raw_flags, device: str) -> str:
    app_flags = raw_flags
    if isinstance(app_flags, str):
        app_flags = int(app_flags, 16) if app_flags.startswith("0x") else int(app_flags)
    # Add the BLE support flag for devices that have Bluetooth.
    if device in ["nanox", "stax", "flex", "apex_m", "apex_p"]:
        app_flags = app_flags | 0x200
    return "0x{:03x}".format(app_flags)


def build_variant(ledger: Dict, overrides: Dict, version: str,
                  device: str, rust_target: str, c_target: str) -> Optional[Dict]:
    # Build the manifest entry for a single variant. 'overrides' is the
    # '[package.metadata.ledger.variants.N]' sub-table ({} for the base app).
    # A variant inherits every field from the base app and may override any of
    # them (name, per-device icon, flags, curve, path).
    # Returns None when neither the variant nor the base app targets the current
    # device, meaning this variant is simply not built for it.
    icon = device_icon(overrides, rust_target) or device_icon(ledger, rust_target)
    if icon is None:
        return None

    return {
        "appFlags": format_app_flags(overrides.get("flags", ledger["flags"]), device),
        "curve": overrides.get("curve", ledger["curve"]),
        "path": overrides.get("path", ledger["path"]),
        "GLYPH_FILES": "/opt/nanos-secure-sdk/fake_glyph",  # To please check_icons.sh
        "ICONNAME": icon,
        "TARGET": c_target,
        "APPNAME": overrides.get("name", ledger["name"]),
        "APPVERSION": version
    }


def build_manifest(metadata: Dict, device: str, app_build_path) -> Dict:
    rust_target, c_target = resolve_targets(device)

    # A Cargo workspace can bundle several app packages; each is a package
    # carrying a '[package.metadata.ledger]' section. Non-app members (helper
    # crates) don't have one and are ignored.
    ledger_packages: List[Dict] = [
        pkg for pkg in metadata.get("packages", [])
        if isinstance(pkg.get("metadata"), dict) and "ledger" in pkg["metadata"]
    ]
    if not ledger_packages:
        raise ValueError("No '[package.metadata.ledger]' section found in the Cargo workspace")

    variants: Dict[str, Dict] = {}
    for package in ledger_packages:
        ledger = package["metadata"]["ledger"]
        version = package["version"]

        # The base app (built without any variant feature) is one variant, and
        # each '[package.metadata.ledger.variants.N]' sub-table adds another
        # (built with '--features' enabling 'ledger_device_sdk/variant_N').
        candidates = {ledger.get("name"): {}}
        for variant_id, overrides in ledger.get("variants", {}).items():
            name = overrides.get("name") or f"{ledger.get('name')}_variant_{variant_id}"
            candidates[name] = overrides

        for name, overrides in candidates.items():
            entry = build_variant(ledger, overrides, version, device, rust_target, c_target)
            if entry is None:
                print(f"Skipping variant '{name}': no '{rust_target}' target defined")
                continue
            print(f"Found variant: {name}")
            variants[name] = entry

    if not variants:
        raise ValueError(f"None of the {len(ledger_packages)} Ledger package(s) "
                         f"target device '{device}'")

    return {
        "BUILD_DIRECTORY": app_build_path,
        "VARIANT_PARAM": "NONE",
        "VARIANTS": variants
    }


def save_app_params(device: str, app_build_path: Path, json_path: Path) -> None:
    metadata = run_cmd("cargo metadata --no-deps --format-version 1 --offline -q",
                       cwd=app_build_path)
    metadata = json.loads(metadata)

    ret = build_manifest(metadata, device, app_build_path)

    with open(json_path, "w") as f:
        json.dump(ret, f, indent=4)


if __name__ == "__main__":
    parser = ArgumentParser()

    parser.add_argument("--device",
                        help="device model",
                        required=True,
                        choices=["nanos", "nanox", "nanosp", "stax", "flex", "apex_m", "apex_p"])
    parser.add_argument("--app_build_path",
                        help="App build path, e.g. <app-boilerplate/app>",
                        required=True)
    parser.add_argument("--json_path",
                        help="Json path to store the output",
                        required=True)

    args = parser.parse_args()

    save_app_params(args.device, args.app_build_path, args.json_path)
