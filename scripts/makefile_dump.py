#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
from typing import Tuple, List, Dict, Optional, Set
from tempfile import NamedTemporaryFile
import json
import os
import re
import shutil
import subprocess
import sys
from utils import run_cmd


# ANSI colors mirroring scripts/logger.sh so this script's diagnostics are
# visually consistent with the surrounding bash checks. Emitted unconditionally
# (CI renders them) and written to stderr.
_COLOR_OFF = "\033[0m"
_FG_TEXT = "\033[1;38;5;15m"
_BG_ERROR = "\033[48;5;52m"
_FG_ERROR = "\033[1;38;5;196m"


def log_error(msg: str) -> None:
    print(
        f"{_FG_ERROR}{_BG_ERROR}Error: {_COLOR_OFF}{_FG_TEXT}{_BG_ERROR}{msg}{_COLOR_OFF}",
        file=sys.stderr,
    )


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


def get_app_listparams(app_build_path: Path, variant_param: str) -> Dict:
    with NamedTemporaryFile(suffix=".mk") as tmp:
        tmp_file = Path(tmp.name)

        with open(tmp_file, "w") as f:
            f.write(LISTPARAMS_MAKEFILE)

        ret = run_cmd(
            f"make -f Makefile -f {tmp_file} listparams {variant_param}",
            cwd=app_build_path,
        )

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


def find_nm() -> Optional[str]:
    """Locate a 'nm' able to read the (ARM) app ELF."""
    for candidate in ("arm-none-eabi-nm", "nm"):
        if shutil.which(candidate):
            return candidate
    return None


def _basename_noext(path: str) -> str:
    """Return the basename of a file without its extension."""
    return os.path.splitext(os.path.basename(path))[0]


def find_app_elf(app_build_path: Path, target: Optional[str]) -> Optional[Path]:
    """Locate the application ELF for the given Makefile TARGET.

    The application is built beforehand (upstream in CI, or locally by the developer)
    and the SDK always places the binary at 'build/<TARGET>/bin/app.elf'.
    When no binary is available, None is returned and the full glyph list is kept (no filtering).
    """
    if not target:
        return None
    elf = Path(app_build_path) / "build" / target / "bin" / "app.elf"
    return elf if elf.is_file() else None


def get_embedded_glyphs(elf: Path) -> Optional[Set[str]]:
    """Return the set of glyph names actually embedded in the binary.

    Each glyph file 'X.ext' is emitted by icon2glyph.py as a 'C_<X>_bitmap' symbol.
    Thanks to '-fdata-sections -Wl,--gc-sections', unreferenced glyphs are dropped
    at link time, so the ELF symbol table reflects what is *really* shipped.

    Returns None when the symbols could not be read at all (no 'nm' tool, or 'nm'
    failure): in that case the caller keeps the full glyph list (safe fallback).
    A successful read returns a set, which may legitimately be empty when the
    binary embeds no app glyph (e.g. a plugin on Nano, where the host app owns the UI).
    """
    nm = find_nm()
    if nm is None:
        print("WARNING: no 'nm' tool found, skipping glyph filtering")
        return None

    ret = subprocess.run(
        [nm, str(elf)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if ret.returncode != 0:
        print(
            f"WARNING: '{nm}' failed to read symbols from {elf}, skipping glyph filtering"
        )
        return None
    return set(re.findall(r"\bC_([A-Za-z0-9_]+)_bitmap\b", ret.stdout))


def is_sdk_glyph(path: str) -> bool:
    """Check if a glyph comes from the SDK.

    SDK glyphs have absolute paths (make expands $(BOLOS_SDK) before we see them).
    """
    return os.path.isabs(path)


def should_filter_sdk_glyph(path: str) -> bool:
    """Check if an SDK glyph should be filtered out (wallet/nano/lib_ux)."""
    # Check for directories to filter
    filter_patterns = [
        "/lib_nbgl/glyphs/wallet/",
        "/lib_nbgl/glyphs/nano/",
        "/lib_ux/glyphs/",
    ]
    return any(pattern in path for pattern in filter_patterns)


def get_accepted_geometries_for_target(target: str) -> Set[str]:
    """Return accepted glyph geometries for a given target/device.

    Matches the logic from check_icons.sh to ensure consistency.
    Returns a set of geometry strings in "WxH" format (e.g., "32x32", "14x14").
    """
    assert target, "Invalid target"

    target_lower = target.lower()

    # Match device patterns from check_icons.sh
    if target_lower == "nanos":
        return {"16x16"}
    if target_lower in ("nanox", "nanos2"):
        return {"14x14", "16x16"}
    if target_lower in ("apex", "apex_m", "apex_p"):
        return {"24x24", "32x32", "48x48"}
    if target_lower == "flex":
        return {"40x40", "64x64"}
    if target_lower == "stax":
        return {"32x32", "64x64"}
    # Unknown target
    assert False, f"No supported glyph sizes defined for target '{target}'"


def get_glyph_dimensions(glyph_path: str, app_build_path: Path) -> str:
    """Get the actual dimensions of a glyph file using 'identify'.

    Returns a geometry string in "WxH" format (e.g., "32x32").
    Raises an exception if the file cannot be read (this is a build/configuration error).
    """
    full_path = app_build_path / glyph_path

    if not full_path.exists():
        raise FileNotFoundError(f"Glyph file not found: {glyph_path}")

    try:
        # Use identify from ImageMagick to get dimensions
        result = subprocess.run(
            ["identify", "-format", "%wx%h", str(full_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            timeout=5,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        raise RuntimeError(
            f"'identify' failed to read {glyph_path}: {result.stderr.strip()}"
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"'identify' timed out reading {glyph_path}")
    except (ValueError, FileNotFoundError) as e:
        raise RuntimeError(f"Failed to get dimensions for {glyph_path}: {e}")


def filter_embedded_glyphs(
    glyph_files: str,
    embedded: Set[str],
    iconname: Optional[str],
    app_build_path: Path,
    accepted_geometries: Set[str],
) -> str:
    """Reduce GLYPH_FILES to the glyphs actually embedded in the binary.

    For SDK glyphs:
    - Filter out glyphs from wallet/, nano/, lib_ux/glyphs/ directories
    - Keep all other SDK glyphs

    For app glyphs:
    - Filter out app glyphs that are copies of SDK glyphs (same basename), even if embedded
    - Use 'identify' to get the actual dimensions of each remaining app glyph
    - Keep app glyphs whose geometry matches accepted geometries for this target
    - Keep ICONNAME and embedded glyphs (unless they are SDK copies as per above)
    """
    # First pass: collect ALL SDK glyph basenames (including filtered ones)
    # This allows detecting app glyphs that are copies of SDK glyphs,
    # even if the SDK originals are filtered (wallet/nano/lib_ux).
    sdk_glyph_basenames = set()
    for glyph in glyph_files.split():
        if is_sdk_glyph(glyph):
            sdk_glyph_basenames.add(_basename_noext(glyph))

    kept = []
    for glyph in glyph_files.split():
        # Handle SDK glyphs
        if is_sdk_glyph(glyph):
            # Filter out wallet/nano/lib_ux directories
            if should_filter_sdk_glyph(glyph):
                continue
            kept.append(glyph)
            continue

        # Handle app glyphs
        bn = _basename_noext(glyph)

        # Filter out app glyphs that are copies of SDK glyphs (same basename)
        # These are checked on the SDK side and shouldn't be re-checked here
        if bn in sdk_glyph_basenames:
            continue

        # Always keep glyphs with embedded symbols or ICONNAME
        if bn in embedded or glyph == iconname:
            kept.append(glyph)
            continue

        # Check if glyph geometry matches accepted geometries
        dims = get_glyph_dimensions(glyph, app_build_path)
        if dims in accepted_geometries:
            kept.append(glyph)

    return " ".join(kept)


def save_app_params(app_build_path: Path, json_path: Path) -> None:

    # Retrieve available variants
    variant_param_name, variants = get_app_listvariants(app_build_path)

    ret = {
        "BUILD_DIRECTORY": str(app_build_path),
        "VARIANT_PARAM": variant_param_name,
        "VARIANTS": {},
        "IS_ALLOWED_MAKEFILE": is_allowed_makefile(app_build_path),
    }

    for variant in variants:
        print(f"Checking for variant: {variant}")

        app_params = get_app_listparams(
            app_build_path, variant_param=f"{variant_param_name}={variant}"
        )

        ret["VARIANTS"][variant] = app_params

    # If the application has been built, reduce the listed glyphs to the ones
    # actually embedded in the binary (the SDK garbage-collects unused glyphs).
    target = next(
        (v.get("TARGET") for v in ret["VARIANTS"].values() if v.get("TARGET")), None
    )
    elf = find_app_elf(app_build_path, target)
    embedded = get_embedded_glyphs(elf) if elf is not None else None

    if embedded is not None:
        # 'embedded' may be empty: the binary genuinely embeds no app glyph (e.g. a
        # plugin on Nano). We still filter, so glyphs that don't belong to this device
        # (wrong geometry) are dropped instead of wrongly checked against it.
        print(f"Filtering glyphs against {len(embedded)} embedded symbol(s) from {elf}")
        # Get accepted geometries for this target/device
        accepted_geometries = get_accepted_geometries_for_target(target)
        print(
            f"Accepted glyph geometries for target '{target}': {sorted(accepted_geometries)}"
        )
        for variant, params in ret["VARIANTS"].items():
            if "GLYPH_FILES" not in params:
                continue
            params["GLYPH_FILES"] = filter_embedded_glyphs(
                params["GLYPH_FILES"],
                embedded,
                params.get("ICONNAME"),
                app_build_path,
                accepted_geometries,
            )
    else:
        # No filtering possible: either the binary is missing, or its symbols could
        # not be read. Without filtering, the full glyph list would be checked, so
        # glyphs that are not actually embedded for this device (e.g. wrong geometry)
        # would raise false errors downstream. This almost always means the app was
        # not built before running the check, so fail with an explicit message.
        if elf is None:
            reason = (
                f"no application binary found at 'build/{target}/bin/app.elf'"
                if target
                else "no application binary found (TARGET is undefined)"
            )
        else:
            reason = f"could not read the symbols of '{elf}'"
        log_error(
            f"Cannot filter glyphs: {reason}.\n"
            "       Glyphs that are not embedded for this device (e.g. with a wrong "
            "geometry)\n"
            "       would be checked anyway and raise false errors.\n"
            "       Build the application first (e.g. run 'make') before running this "
            "check."
        )
        sys.exit(1)

    with open(json_path, "w") as f:
        json.dump(ret, f, indent=4)


def is_allowed_makefile(app_build_path: Path) -> bool:
    makefile_path = os.path.join(app_build_path, "Makefile")

    # list of the allowed makefiles included in the app Makefile
    allowed_makefiles = [
        "Makefile.standard_app",  # standard app Makefile
        "include lib-app-bitcoin/Makefile",  # Bitcoin clone makefiles
        "include bitcoin_app_base/Makefile",  # Bitcoin clone makefiles
        "include ethereum-plugin-sdk/standard_plugin.mk",  # Ethereum plugin makefiles
        "ledger-zxlib/makefiles",  # Zondax like makefiles
    ]

    with open(makefile_path, "r") as f:
        for line in f:
            stripped_line = line.strip()
            if any(
                allowed_makefile in stripped_line and not stripped_line.startswith("#")
                for allowed_makefile in allowed_makefiles
            ):
                return True

    return False


if __name__ == "__main__":
    parser = ArgumentParser()

    parser.add_argument(
        "--app_build_path",
        help="App build path, e.g. <app-boilerplate/app>",
        required=True,
    )
    parser.add_argument(
        "--json_path", help="Json path to store the output", required=True
    )

    args = parser.parse_args()

    save_app_params(Path(args.app_build_path), Path(args.json_path))
