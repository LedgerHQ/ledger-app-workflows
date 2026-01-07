#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import json
from utils import run_cmd


def save_app_params(device: str, app_build_path: Path, json_path: Path) -> None:
    metadata = run_cmd("cargo +$RUST_NIGHTLY metadata --no-deps --format-version 1 --offline -q",
                       cwd=app_build_path)
    metadata = json.loads(metadata)

    rust_target = device
    c_target = device
    if device == "nanosp":
        rust_target = "nanosplus"
        c_target = "nanos2"

    # find package with metadata.ledger
    packages = metadata.get("packages", [])
    package = next((pkg for pkg in packages if "metadata" in pkg and pkg["metadata"] is not None and "ledger" in pkg["metadata"]),None)

    variant = package["name"]
    appname = package["metadata"]["ledger"]["name"]
    appversion = package["version"]
    iconname = package["metadata"]["ledger"][rust_target]["icon"]
    glyph_files = "/opt/nanos-secure-sdk/fake_glyph"  # To please check_icons.sh

    app_flags = package["metadata"]["ledger"]["flags"]
    if app_flags.startswith("0x"):
        app_flags = int(app_flags, 16)
    else:
        app_flags = int(app_flags)
    if device in ["nanox", "stax", "flex", "apex_m", "apex_p"]:
        app_flags = app_flags | 0x200
    app_flags = "0x{:03x}".format(app_flags)

    app_curve = package["metadata"]["ledger"]["curve"]

    app_path = package["metadata"]["ledger"]["path"]

    ret = {
        "BUILD_DIRECTORY": app_build_path,
        "VARIANT_PARAM": "NONE",
        "VARIANTS": {
            variant: {
                "appFlags": app_flags,
                "curve": app_curve,
                "path": app_path,
                "GLYPH_FILES": glyph_files,
                "ICONNAME": iconname,
                "TARGET": c_target,
                "APPNAME": appname,
                "APPVERSION": appversion
            }
        }
    }

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
