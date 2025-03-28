#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
from typing import Tuple, List, Dict
from tempfile import NamedTemporaryFile
import json
import os
from utils import run_cmd


LISTPARAMS_MAKEFILE = """
listparams:
\t@echo Start dumping params
\t@echo APP_LOAD_PARAMS=$(APP_LOAD_PARAMS)
\t@echo GLYPH_FILES=$(GLYPH_FILES)
\t@echo ICONNAME=$(ICONNAME)
\t@echo TARGET=$(TARGET)
\t@echo TARGET_NAME=$(TARGET_NAME)
\t@echo TARGET_ID=$(TARGET_ID)
\t@echo APPNAME=$(APPNAME)
\t@echo APPVERSION=$(APPVERSION)
\t@echo API_LEVEL=$(API_LEVEL)
\t@echo SDK_NAME=$(SDK_NAME)
\t@echo SDK_VERSION=$(SDK_VERSION)
\t@echo SDK_HASH=$(SDK_HASH)
\t@echo appFlags=$(APP_FLAGS_APP_LOAD_PARAMS)
\t@echo curve=$(CURVE_APP_LOAD_PARAMS)
\t@echo path=$(PATH_APP_LOAD_PARAMS)
\t@echo path_slip21=$(PATH_SLIP21_APP_LOAD_PARAMS)
\t@echo tlvraw=$(TLVRAW_APP_LOAD_PARAMS)
\t@echo dep=$(DEP_APP_LOAD_PARAMS)
\t@echo nocrc=$(ENABLE_NOCRC_APP_LOAD_PARAMS)
\t@echo Stop dumping params
"""


def get_app_listvariants(app_build_path: Path) -> Tuple[str, List[str]]:
    # Using listvariants Makefile target
    listvariants = run_cmd("make listvariants", cwd=app_build_path)
    if "VARIANTS" not in listvariants:
        raise ValueError(f"Invalid variants retrieved: {listvariants}")

    # Drop Makefile logs previous to listvariants output
    listvariants = listvariants.split("VARIANTS ")[1]
    listvariants = listvariants.split("\n")[0]

    variants = listvariants.split(" ")
    variant_param_name = variants.pop(0)
    assert variants, "At least one variant should be defined in the app Makefile"
    return variant_param_name, variants


def get_app_listparams(app_build_path: Path,
                       variant_param: str) -> Dict:
    with NamedTemporaryFile(suffix='.mk') as tmp:
        tmp_file = Path(tmp.name)

        with open(tmp_file, "w") as f:
            f.write(LISTPARAMS_MAKEFILE)

        ret = run_cmd(f"make -f Makefile -f {tmp_file} listparams {variant_param}",
                      cwd=app_build_path)

    ret = ret.split("Start dumping params\n")[1]
    ret = ret.split("\nStop dumping params")[0]

    listparams = {}
    for line in ret.split("\n"):
        if "=" not in line:
            continue

        if "APP_LOAD_PARAMS=" in line:
            app_load_params_str = line.replace("APP_LOAD_PARAMS=", "")
            listparams["APP_LOAD_PARAMS"] = app_load_params_str
        else:
            key, value = line.split("=")
            if not value:
                # Exclude Makefile variable with no value
                continue
            if key in ["curve", "path", "tlvraw", "dep"]:
                # Exposes as list when multiple value can be used
                value = value.strip().split(" ")
            listparams[key] = value

    # "path" and "appFlags" params should always be present
    if "path" not in listparams:
        listparams["path"] = [None]
    if "appFlags" not in listparams:
        listparams["appFlags"] = "0x000"

    return listparams


def save_app_params(app_build_path: Path, json_path: Path) -> None:

    # Retrieve available variants
    variant_param_name, variants = get_app_listvariants(app_build_path)

    ret = {
        "BUILD_DIRECTORY": app_build_path,
        "VARIANT_PARAM": variant_param_name,
        "VARIANTS": {},
        "IS_ALLOWED_MAKEFILE": is_allowed_makefile(app_build_path)
    }

    for variant in variants:
        print(f"Checking for variant: {variant}")

        app_params = get_app_listparams(app_build_path,
                                        variant_param=f"{variant_param_name}={variant}")

        ret["VARIANTS"][variant] = app_params

    with open(json_path, "w") as f:
        json.dump(ret, f, indent=4)


def is_allowed_makefile(app_build_path: Path) -> bool:
    makefile_path = os.path.join(app_build_path, "Makefile")

    # list of the allowed makefiles included in the app Makefile
    allowed_makefiles = [
        "ledger-zxlib/makefiles", # Zondax like makefiles
        "Makefile.standard_app", # standard app Makefile
        "include lib-app-bitcoin/Makefile", # Bitcoin clone makefiles 
        "include bitcoin_app_base/Makefile", # Bitcoin clone makefiles 
        "include ethereum-plugin-sdk/standard_plugin.mk" # Ethereum plugin makefiles
    ]

    with open(makefile_path, "r") as f:
        for line in f:
            stripped_line = line.strip()
            if any(allowed_makefile in stripped_line and not stripped_line.startswith("#")
                   for allowed_makefile in allowed_makefiles):
                return True

    return False


if __name__ == "__main__":
    parser = ArgumentParser()

    parser.add_argument("--app_build_path",
                        help="App build path, e.g. <app-boilerplate/app>",
                        required=True)
    parser.add_argument("--json_path",
                        help="Json path to store the output",
                        required=True)

    args = parser.parse_args()

    save_app_params(args.app_build_path, args.json_path)
