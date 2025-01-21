import json
import logging
from argparse import ArgumentParser
from dataclasses import asdict, dataclass
from ledgered.github import AppRepository, Condition, GitHubLedgerHQ, NoManifestException

LOGGER_FORMAT = "[%(asctime)s][%(levelname)s] %(name)s - %(message)s"
logging.root.handlers.clear()
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter(LOGGER_FORMAT))
logging.root.addHandler(handler)

devices = ["nanos", "nanos+", "nanox", "flex", "stax"]


@dataclass
class AppInfo:
    default_branch: str
    devices: list[str]
    name: str
    repository: str

    def __init__(self, app: AppRepository, filtered_devices: set[str]):
        self.default_branch = app.default_branch
        compatible_devices = app.manifest.app.devices
        self.devices = '["' + '", "'.join(compatible_devices.intersection(filtered_devices)) + '"]'
        self.name = app.name
        self.repository = f"LedgerHQ/{app.name}"


def arg_parse():
    parser = ArgumentParser("Selects applications and dump relevant workflow data from their "
                            "manifests as a JSON")
    parser.add_argument("-d",
                        "--devices",
                        nargs="+",
                        required=False,
                        default="all",
                        choices=["nanos", "nanosp", "nanos+", "nanox", "flex", "stax", "all"],
                        help="Devices to filter on. Accepts several successive values (separated "
                        "with space). Valid values are 'nanos', 'nanosp', 'nanos+', 'nanox', "
                        "'stax', 'flex', 'all'.")
    parser.add_argument("-e",
                        "--exclude",
                        nargs="+",
                        required=False,
                        default=list(),
                        help="Application to exclude from the list. Accepts several successive "
                        "values (separated with space).")
    parser.add_argument("-o",
                        "--only",
                        nargs="+",
                        required=False,
                        default=list(),
                        help="List of applications to select. Accepts several successive values "
                        "(separated with space). Takes precendence other `--exclude` (applications "
                        "in both list will be selected)")
    parser.add_argument("-l",
                        "--limit",
                        required=False,
                        default=0,
                        type=int,
                        help="Limit the number of application to collect (testing purpose for "
                        "instance)")
    parser.add_argument("-s",
                        "--sdk",
                        required=False,
                        default="all",
                        type=str,
                        choices=["C", "c", "Rust", "rust", "all"],
                        help="SDK to filter on. Only apps using the SDK are selected. Defaults to "
                        "'all'")
    parser.add_argument("-t",
                        "--github_token",
                        required=False,
                        default="",
                        type=str,
                        help="A GitHub token to avoid GH API limitation")
    parser.add_argument("-v", "--verbose", action="count", default=0)

    args = parser.parse_args()

    selected_devices = list()
    for d in args.devices:
        if d.lower() == "nanosp":
            d = "nanos+"
        if d.lower() in devices:
            selected_devices.append(d)
            continue
        if d.lower() == "all":
            selected_devices = devices
            break
        logging.warning(f"Unknown device target '{d}'. Ignoring.")
    args.devices = selected_devices

    # lowering every string in the exclude or only lists, easier to compare
    if args.only:
        # `only` takes precedence over `exclude`, so `exclude` is emptied (ignored)
        args.only = [name.lower() for name in args.only]
        args.exclude = []
    else:
        args.exclude = [name.lower() for name in args.exclude]

    return args


def main():
    args = arg_parse()

    if args.verbose == 1:
        logging.root.setLevel(logging.INFO)
    elif args.verbose > 1:
        logging.root.setLevel(logging.DEBUG)

    selected_devices = set(args.devices)

    logging.info("Fetching application repositories from GitHub")
    if args.github_token:
        gh = GitHubLedgerHQ(args.github_token)
    else:
        gh = GitHubLedgerHQ()
    apps = gh.apps.filter(archived=Condition.WITHOUT, private=Condition.WITHOUT)

    selected_sdk: list[str]
    if args.sdk.lower() == "all":
        selected_sdk = ["c", "rust"]
    else:
        selected_sdk = [args.sdk.lower()]

    selected_apps = list()
    for app in apps:
        if ((args.limit != 0 and len(selected_apps) >= args.limit)
                or (selected_apps and len(selected_apps) == len(args.only))):
            break

        logging.info(f"Managing app '{app.name}'")
        try:
            if args.only and app.name.lower() not in args.only:
                logging.debug("App not selected, ignoring.")
                continue
            if app.name.lower() in args.exclude:
                logging.debug("Excluding this app")
                continue
            if app.manifest.app.sdk not in selected_sdk:
                logging.debug("Wrong SDK, ignoring this app")
                continue
            selected_apps.append(asdict(AppInfo(app, selected_devices)))
        except NoManifestException:
            logging.warning(f"Application '{app.name}' has no manifest! Ignoring.")

    print(json.dumps(selected_apps))


if __name__ == "__main__":
    main()
