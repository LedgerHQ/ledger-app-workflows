#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import json
from utils import run_cmd


def save_app_params(device: str, app_build_path: Path, json_path: Path) -> None:
    metadata = run_cmd("cargo metadata --no-deps --format-version 1 --offline -q",
                       cwd=app_build_path)
    metadata = json.loads(metadata)

    rust_target = device
    c_target = device
    if device == "nanosp":
        rust_target = "nanosplus"
        c_target = "nanos2"

    variant = metadata["packages"][0]["name"]
    appname = metadata["packages"][0]["metadata"]["ledger"]["name"]
    appversion = metadata["packages"][0]["version"]
    iconname = metadata["packages"][0]["metadata"]["ledger"][rust_target]["icon"]
    glyph_files = "/opt/nanos-secure-sdk/fake_glyph"  # To please check_icons.sh

    # Generate partial app_load_flags for ledger-app-database comparison only
    app_load_flags = f"--appName {appname}"

    appFlags = int(metadata["packages"][0]["metadata"]["ledger"]["flags"])
    if device in ["nanox", "stax"]:
        appFlags = appFlags | 0x200
    appFlags = "0x{:03x}".format(appFlags)
    app_load_flags += f" --appFlags {appFlags}"

    for curve in metadata["packages"][0]["metadata"]["ledger"]["curve"]:
        app_load_flags += f" --curve {curve}"

    for path in metadata["packages"][0]["metadata"]["ledger"]["path"]:
        app_load_flags += f" --path {path}"

    ret = {
        "BUILD_DIRECTORY": app_build_path,
        "VARIANT_PARAM": "NONE",
        "VARIANTS": {
            variant: {
                "APP_LOAD_PARAMS": app_load_flags,
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
                        choices=["nanos", "nanox", "nanosp", "stax"])
    parser.add_argument("--app_build_path",
                        help="App build path, e.g. <app-boilerplate/app>",
                        required=True)
    parser.add_argument("--json_path",
                        help="Json path to store the output",
                        required=True)

    args = parser.parse_args()

    save_app_params(args.device, args.app_build_path, args.json_path)
