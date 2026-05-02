#!/usr/bin/env bash

set -euo pipefail

SHOW_VALUES=false
SHOW_PATHS=false
INCLUDE_NOISY=false

usage() {
  cat <<'EOF'
Usage: prefs-diff.sh [--values] [--paths] [--include-noisy]

List macOS preference domains and keys currently written on this machine.

Options:
  --values  Include compact value previews, with sensitive-looking keys redacted
  --paths   Include the plist path for each key
  --include-noisy  Include noisy Apple service/cache domains
  -h, --help  Show this help
EOF
}

die() {
  printf 'prefs-diff: %s\n' "$1" >&2
  exit 1
}

while (($#)); do
  case "$1" in
  --values)
    SHOW_VALUES=true
    shift
    ;;
  --paths)
    SHOW_PATHS=true
    shift
    ;;
  --include-noisy)
    INCLUDE_NOISY=true
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    die "unknown argument: $1"
    ;;
  esac
done

python3 - "$SHOW_VALUES" "$SHOW_PATHS" "$INCLUDE_NOISY" <<'PY'
import glob
import os
import plistlib
import re
import sys

show_values = sys.argv[1] == "true"
show_paths = sys.argv[2] == "true"
include_noisy = sys.argv[3] == "true"
home = os.path.expanduser("~")

uuid_suffix = re.compile(
    r"\.[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
)
sensitive_key = re.compile(r"(account|auth|credential|email|key|password|secret|token)", re.I)
noisy_domains = {
    "APMAnalyticsSuiteName",
    "APMExperimentSuiteName",
    "Avatar Cache Index",
    "ContextStoreAgent",
    "diagnostics_agent",
    "familycircled",
    "loginwindow",
    "mbuseragent",
    "MiniLauncher",
    "MobileMeAccounts",
    "pbs",
    "TokenBucketRateLimiter",
    "com.Breakpad.crash_report_sender",
    "com.Facepunch-Studios-LTD.Rust",
    "com.luisurrutia.dotfiles",
    "com.adobe.crashreporter",
    "com.adobe.dunamis",
    "com.apple.Accessibility.Assets",
    "com.apple.AccessibilityHearingNearby",
    "com.apple.AccessibilityUIServer",
    "com.apple.AccessibilityVisualsAgent",
    "com.apple.AdLib",
    "com.apple.AdPlatforms",
    "com.apple.AddressBook",
    "com.apple.AddressBook.abd",
    "com.apple.AMPLibraryAgent",
    "com.apple.AOSKit.RegInfo",
    "com.apple.AOSPushRelay.TopicInfo",
    "com.apple.AppStore",
    "com.apple.AppStoreComponents",
    "com.apple.AppleMediaServices",
    "com.apple.AppleMediaServices.notbackedup",
    "com.apple.AppleMultitouchMouse",
    "com.apple.AppleMultitouchTrackpad",
    "com.apple.AssetMetricsWorker",
    "com.apple.AudioAccessory",
    "com.apple.AuthKit",
    "com.apple.AuthKit.AgeRangeSettingsCache",
    "com.apple.AuthenticationServicesCore.AuthenticationServicesAgent",
    "com.apple.AvatarUI.Staryu",
    "com.apple.CallHistorySyncHelper",
    "com.apple.CharacterPaletteIM",
    "com.apple.CharacterPicker",
    "com.apple.ClassKit-Settings.extension",
    "com.apple.CloudKit",
    "com.apple.CloudSharingUI.AddParticipants",
    "com.apple.CloudTelemetryService.xpc",
    "com.apple.ComfortSounds",
    "com.apple.CommCenter.counts",
    "com.apple.CoreDuet",
    "com.apple.CoreGraphics",
    "com.apple.CoreSimulator",
    "com.apple.CrashReporter",
    "com.apple.DPSubmissionService",
    "com.apple.DataDeliveryServices",
    "com.apple.DiagnosticExtensions.extensionTracker",
    "com.apple.DictionaryServices",
    "com.apple.DiskUtility",
    "com.apple.DuetExpertCenter.AppPredictionExpert",
    "com.apple.DuetExpertCenter.MagicalMoments",
    "com.apple.EmojiCache",
    "com.apple.EscrowSecurityAlert",
    "com.apple.ExtensionsPreferences.ShareMenu",
    "com.apple.FaceTime",
    "com.apple.FamilyCircle",
    "com.apple.FinanceKit",
    "com.apple.FolderActionsDispatcher",
    "com.apple.FontRegistry.user",
    "com.apple.GEO",
    "com.apple.GameController",
    "com.apple.GamePolicyAgent",
    "com.apple.GenerativeFunctions.GenerativeFunctionsInstrumentation",
    "com.apple.HIToolbox",
    "com.apple.HearingAids",
    "com.apple.IMAutomaticHistoryDeletionAgent",
    "com.apple.IMCoreSpotlight",
    "com.apple.Keyboard-Settings.extension",
    "com.apple.LaunchServices",
    "com.apple.ManagedClient",
    "com.apple.Maps.mapssync",
    "com.apple.Maps.mapssyncd",
    "com.apple.Messages",
    "com.apple.MobileSMS",
    "com.apple.MobileSMS.CKDNDList",
    "com.apple.MobileSMSPreview",
    "com.apple.NewDeviceOutreach",
    "com.apple.PersonalAudio",
    "com.apple.ProblemReporter",
    "com.apple.QuickLookDaemon",
    "com.apple.ReportCrash",
    "com.apple.SetupAssistant",
    "com.apple.SiriMetricsWorker",
    "com.apple.SiriExperimentMetricsWorker",
    "com.apple.SocialLayer",
    "com.apple.SpeakSelection",
    "com.apple.Spotlight",
    "com.apple.SpotlightResources.Defaults",
    "com.apple.Safari.PasswordBreachAgent",
    "com.apple.SafariBookmarksSyncAgent",
    "com.apple.SafariCloudHistoryPushAgent",
    "com.apple.ScreenTimeSettingsAgent",
    "com.apple.ScriptEditor2",
    "com.apple.ServicesMenu.Services",
    "com.apple.StatusKitAgent",
    "com.apple.StocksKitService",
    "com.apple.StorageManagement.Service",
    "com.apple.TTY",
    "com.apple.TV",
    "com.apple.TelephonyUtilities",
    "com.apple.TelephonyUtilities.sharePlayAppPolicies",
    "com.apple.TextInputMenu",
    "com.apple.TextInputMenuAgent",
    "com.apple.TimeMachine",
    "com.apple.TrustedPeersHelper",
    "com.apple.UnifiedAssetFramework",
    "com.apple.UserAccountUpdater",
    "com.apple.Wallet",
    "com.apple.Wallpaper-Settings.extension",
    "com.apple.WatchListKit",
    "com.apple.WindowManager",
    "com.apple.accessibility.heard",
    "com.apple.accessory.Hearing",
    "com.apple.accounts.suggestions",
    "com.apple.accountsd",
    "com.apple.amp.mediasharingd",
    "com.apple.amsaccountsd",
    "com.apple.amsengagementd",
    "com.apple.animoji",
    "com.apple.anvil.501",
    "com.apple.ap.adprivacyd",
    "com.apple.appkit.xpc.openAndSavePanelService",
    "com.apple.appplaceholdersyncd",
    "com.apple.appleaccount",
    "com.apple.appleaccount.informationcache",
    "com.apple.appleaccountd",
    "com.apple.appleintelligencereporting",
    "com.apple.appplaceholder-syncd",
    "com.apple.appstorecomponentsd",
    "com.apple.appstored",
    "com.apple.assistant",
    "com.apple.assistant.backedup",
    "com.apple.assistant.support",
    "com.apple.assistantd",
    "com.apple.audio.AudioComponentCache",
    "com.apple.backgroundassets.managed",
    "com.apple.biomesyncd",
    "com.apple.bird",
    "com.apple.bird.containers.notifications",
    "com.apple.bluetoothuserd",
    "com.apple.businessservicesd",
    "com.apple.calaccessd",
    "com.apple.cameracapture",
    "com.apple.chronod",
    "com.apple.classroom",
    "com.apple.cloud.quota",
    "com.apple.cloudd",
    "com.apple.cloudpaird",
    "com.apple.cloudphotod",
    "com.apple.cmfsyncagent",
    "com.apple.cmio.ContinuityCaptureAgent",
    "com.apple.commcenter",
    "com.apple.commcenter.callservices",
    "com.apple.commcenter.csidata",
    "com.apple.commcenter.data",
    "com.apple.commerce",
    "com.apple.commerce.knownclients",
    "com.apple.configurationprofiles.user",
    "com.apple.contacts.postersyncd",
    "com.apple.contactsd",
    "com.apple.contextsync.subscriptions",
    "com.apple.coreservices.UASharedPasteboardProgressUI",
    "com.apple.coreservices.uiagent",
    "com.apple.coreservices.useractivityd",
    "com.apple.corespotlightui",
    "com.apple.cseventlistener",
    "com.apple.dataaccess.babysitter",
    "com.apple.dataaccess.dataaccessd",
    "com.apple.diagnosticextensionsd",
    "com.apple.dock.external.extra.arm64",
    "com.apple.donotdisturbd",
    "com.apple.driver.AppleHIDMouse",
    "com.apple.driver.AppleBluetoothMultitouch.mouse",
    "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    "com.apple.dt.Xcode",
    "com.apple.dt.xcodebuild",
    "com.apple.facetime.bag",
    "com.apple.facetimemessagestored",
    "com.apple.fileproviderd",
    "com.apple.financed",
    "com.apple.findmy.findmylocateagent",
    "com.apple.findmy.fmfcore.notbackedup",
    "com.apple.findmy.fmipcore.notbackedup",
    "com.apple.frauddefensed",
    "com.apple.gamecenter",
    "com.apple.gamed",
    "com.apple.games",
    "com.apple.generativeexperiences.corefollowup",
    "com.apple.generativepartnerservicesettings",
    "com.apple.gms.availability",
    "com.apple.helpd",
    "com.apple.homed",
    "com.apple.homed.notbackedup",
    "com.apple.homeenergyd",
    "com.apple.homeeventsd",
    "com.apple.iCloudNotificationAgent",
    "com.apple.ibtool",
    "com.apple.icloud.gm",
    "com.apple.icloud.searchpartyuseragent",
    "com.apple.icloudwebd",
    "com.apple.ids",
    "com.apple.ids.deviceproperties",
    "com.apple.imagecapture",
    "com.apple.imagent",
    "com.apple.imdpersistence.IMDPersistenceAgent",
    "com.apple.imessage",
    "com.apple.imessage.bag",
    "com.apple.imservice.ids.FaceTime",
    "com.apple.imservice.ids.iMessage",
    "com.apple.inputAnalytics.IASGenmojiAnalyzer",
    "com.apple.inputAnalytics.IASGenmojiUsageAnalyzer",
    "com.apple.inputAnalytics.IASImageGenerationCreationAnalyzer",
    "com.apple.identityservicesd",
    "com.apple.imservice.SMS",
    "com.apple.metrickitd",
    "com.apple.settings.storage",
    "com.apple.sharingd",
    "com.apple.siri.sirisuggestions",
    "com.apple.siriactionsd",
    "com.apple.siriinferenced",
    "com.apple.siriknowledged",
    "com.apple.sms",
    "com.apple.sociallayerd",
    "com.apple.sociallayerd.CloudKit.ckwriter",
    "com.apple.speakerrecognition",
    "com.apple.speech.recognition.AppleSpeechRecognition.prefs",
    "com.apple.spotlight.mdwrite",
    "com.apple.spotlightknowledge",
    "com.apple.spotlightknowledged.pipeline",
    "com.apple.stickersd",
    "com.apple.stockholm",
    "com.apple.stocks.stockskit",
    "com.apple.studentd",
    "com.apple.suggestd",
    "com.apple.suggestions",
    "com.apple.suggestions.TextUnderstandingObserver",
    "com.apple.symbolichotkeys",
    "com.apple.sync.NanoHome",
    "com.apple.syncdefaultsd",
    "com.apple.systemsettings.extensions",
    "com.apple.talagent",
    "com.apple.textInput.keyboardServices.textReplacement",
    "com.apple.tipsd",
    "com.apple.translationd",
    "com.apple.transparencyd",
    "com.apple.triald",
    "com.apple.unilog.MacMailSearch",
    "com.apple.universalaccess",
    "com.apple.universalaccessAuthWarning",
    "com.apple.voiceservices",
    "com.apple.voicetrigger",
    "com.apple.voicetrigger.notbackedup",
    "com.apple.wifi.WiFiAgent",
    "com.apple.xpc.activity2",
    "com.google.gmp.measurement.monitor",
    "com.apple.windowserver.displays",
}
noisy_domain_prefixes = (
    "com.apple.CloudSubscriptionFeatures.",
    "com.segment.storage.",
)


def domain_from_path(path, byhost):
    name = os.path.basename(path)
    if name.endswith(".plist"):
        name = name[:-6]
    if byhost:
        name = uuid_suffix.sub("", name)
    return name


def is_noisy_domain(domain):
    return domain in noisy_domains or domain.startswith(noisy_domain_prefixes)


def value_kind(value):
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "float"
    if isinstance(value, str):
        return "string"
    if isinstance(value, bytes):
        return "data"
    if isinstance(value, list):
        return f"array[{len(value)}]"
    if isinstance(value, dict):
        return f"dict[{len(value)}]"
    if value is None:
        return "null"
    return type(value).__name__


def preview_value(key_path, value):
    if sensitive_key.search(key_path):
        return "<redacted>"
    if isinstance(value, (dict, list)):
        return value_kind(value)
    if isinstance(value, bytes):
        return f"data[{len(value)}]"
    text = str(value).replace("\n", "\\n")
    if len(text) > 80:
        text = f"{text[:77]}..."
    return text


def flatten(prefix, value):
    if isinstance(value, dict):
        for key in sorted(value):
            key_path = f"{prefix}.{key}" if prefix else str(key)
            yield from flatten(key_path, value[key])
        return

    yield prefix, value


def load_plist(path):
    with open(path, "rb") as handle:
        return plistlib.load(handle)


def collect_rows():
    locations = [
        ("user", os.path.join(home, "Library/Preferences/*.plist"), False),
        ("currentHost", os.path.join(home, "Library/Preferences/ByHost/*.plist"), True),
    ]

    for scope, pattern, byhost in locations:
        for path in sorted(glob.glob(pattern)):
            domain = domain_from_path(path, byhost)
            if not include_noisy and is_noisy_domain(domain):
                continue

            try:
                plist = load_plist(path)
            except Exception as error:
                yield [scope, domain, "<unreadable>", type(error).__name__, path]
                continue

            if not isinstance(plist, dict):
                yield [scope, domain, "<root>", value_kind(plist), path]
                continue

            for key_path, value in flatten("", plist):
                row = [scope, domain, key_path, value_kind(value)]
                if show_values:
                    row.append(preview_value(key_path, value))
                if show_paths:
                    row.append(path)
                yield row


columns = ["scope", "domain", "key", "type"]
if show_values:
    columns.append("value")
if show_paths:
    columns.append("path")

rows = sorted(collect_rows(), key=lambda row: tuple(row[:3]))
widths = [len(column) for column in columns]
for row in rows:
    for index, value in enumerate(row):
        widths[index] = min(max(widths[index], len(value)), 80)


def trim(value, width):
    if len(value) <= width:
        return value
    return f"{value[: width - 3]}..."


print("  ".join(column.ljust(widths[index]) for index, column in enumerate(columns)))
print("  ".join("-" * width for width in widths))
for row in rows:
    print("  ".join(trim(value, widths[index]).ljust(widths[index]) for index, value in enumerate(row)))

domains = len({(row[0], row[1]) for row in rows})
print(f"\nSummary: {len(rows)} written preference keys across {domains} domains")
print("Note: this is an inventory of written defaults, not a provable factory-default diff.")
PY
