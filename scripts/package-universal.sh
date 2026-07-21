#!/usr/bin/env bash
# CPA Monitor Bar — Universal 2 controlled-test package builder.
# Generates an arm64+x86_64, ad-hoc-signed macOS 26.5+ test DMG.
# It does NOT launch the app, access credentials, or contact the Keeper service.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT="${1:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"
PRODUCT="CPAMonitorBar"
MIN_OS="26.5"
STAMP="$(date +%Y%m%d-%H%M%S)"
BUILD_ROOT="$(mktemp -d /tmp/cpa-monitor-bar-universal-build.XXXXXX)"

cleanup() {
  rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -f "$PROJECT/Package.swift" ]] || fail "Swift Package not found: $PROJECT"
PROJECT="$(cd "$PROJECT" && pwd -P)"
ICON="$PROJECT/Assets/AppIcon.icns"
VERSION_FILE="$PROJECT/VERSION"
[[ -f "$ICON" ]] || fail "App icon not found: $ICON"
[[ -f "$VERSION_FILE" ]] || fail "Version file not found: $VERSION_FILE"
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
APP_BUILD_NUMBER="${BUILD_NUMBER:-1}"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] \
  || fail "Invalid semantic version: $APP_VERSION"
[[ "$APP_BUILD_NUMBER" =~ ^[0-9]+$ ]] \
  || fail "BUILD_NUMBER must be an integer: $APP_BUILD_NUMBER"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT/dist}"
PACKAGE_BASENAME="$PRODUCT-$APP_VERSION-universal-adhoc-test-$STAMP"
OUT_ROOT="$OUTPUT_DIR/$PACKAGE_BASENAME"
APP="$OUT_ROOT/CPAMonitorBar.app"
EXE="$APP/Contents/MacOS/$PRODUCT"
FRAMEWORKS="$APP/Contents/Frameworks"
DMG="$OUTPUT_DIR/$PACKAGE_BASENAME.dmg"

mkdir -p "$OUTPUT_DIR"
# `swift build` resolves Package.swift from its current directory, not from --build-path.
# Switch into the supplied package root before compiling.
cd "$PROJECT"

find_product() {
  python3 - "$1" "$2" "$3" <<'PY'
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
product = sys.argv[2]
architecture = sys.argv[3]
matches = []
for path in root.rglob(product):
    # Swift release builds also emit CPAMonitorBar.dSYM/.../CPAMonitorBar.
    # Only the actual release executable may be packaged.
    if any(part.endswith(".dSYM") for part in path.parts) or not path.is_file():
        continue
    result = subprocess.run(["lipo", "-archs", str(path)], capture_output=True, text=True)
    if result.returncode == 0 and architecture in result.stdout.split():
        matches.append(path)

if len(matches) != 1:
    raise SystemExit(
        f"expected one {architecture} Mach-O {product}; found: {matches}"
    )
print(matches[0])
PY
}

build_architecture() {
  local architecture="$1"
  local architecture_root="$BUILD_ROOT/$architecture"

  echo "==> Building $architecture release product..."
  swift build \
    --configuration release \
    --triple "$architecture-apple-macosx$MIN_OS" \
    --build-path "$architecture_root" \
    --product "$PRODUCT"
}

build_architecture "arm64"
build_architecture "x86_64"

ARM_BIN="$(find_product "$BUILD_ROOT/arm64" "$PRODUCT" "arm64")"
X86_BIN="$(find_product "$BUILD_ROOT/x86_64" "$PRODUCT" "x86_64")"
echo "arm64 executable: $ARM_BIN"
echo "x86_64 executable: $X86_BIN"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$FRAMEWORKS"
lipo -create "$ARM_BIN" "$X86_BIN" -output "$EXE"
chmod 755 "$EXE"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>CPAMonitorBar</string>
  <key>CFBundleIdentifier</key><string>com.wangzhiwen.CPAMonitorBar.controlled-test</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>CPA Monitor Bar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>$APP_BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>26.5</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key><true/>
  </dict>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cat > "$OUT_ROOT/TESTING.md" <<README
# CPA Monitor Bar — Universal 2 Controlled Test Package

- Version: $APP_VERSION ($APP_BUILD_NUMBER)
- Supports Apple Silicon (arm64) and Intel (x86_64) Macs running macOS 26.5 or later.
- This is a controlled test package with an ad-hoc signature only.
- It is not Developer ID signed, notarized, or stapled. If macOS requests it, use Finder's normal Open / Privacy & Security confirmation flow. Do not disable Gatekeeper or remove quarantine attributes.
- The app is menu-bar only and may not show a Dock icon.
- In the DMG, drag CPAMonitorBar.app onto the Applications shortcut to install it.
- Configure the CPA Usage Keeper address and administrator password manually in the app.
- No password, cookie, token, .env file, or local configuration is included in this package.
README

echo "==> Copying required Swift runtime libraries..."
SWIFT_STDLIB_TOOL="$(xcrun --find swift-stdlib-tool)"
"$SWIFT_STDLIB_TOOL" \
  --copy \
  --platform macosx \
  --scan-executable "$EXE" \
  --unsigned-destination "$FRAMEWORKS"

echo "==> Removing build-machine Swift rpaths and adding bundle-relative Frameworks rpath..."
python3 - "$EXE" <<'PY'
import re
import subprocess
import sys

exe = sys.argv[1]
output = subprocess.check_output(["otool", "-l", exe], text=True)
lines = output.splitlines()
rpaths = []
for i, line in enumerate(lines):
    if line.strip() == "cmd LC_RPATH":
        for candidate in lines[i + 1:i + 6]:
            match = re.match(r"\s*path (.+) \(offset \d+\)", candidate)
            if match:
                rpaths.append(match.group(1))
                break

for rpath in dict.fromkeys(rpaths):
    if rpath.startswith("/") and ("/Toolchains/" in rpath or "/usr/lib/swift-" in rpath):
        subprocess.run(["install_name_tool", "-delete_rpath", rpath, exe], check=True)

relative = "@executable_path/../Frameworks"
updated = subprocess.check_output(["otool", "-l", exe], text=True)
if relative not in updated:
    subprocess.run(["install_name_tool", "-add_rpath", relative, exe], check=True)
PY

echo "==> Applying ad-hoc signatures to copied runtime libraries and app bundle..."
python3 - "$FRAMEWORKS" <<'PY'
from pathlib import Path
import subprocess
import sys

for item in sorted(Path(sys.argv[1]).rglob("*")):
    if item.is_file():
        subprocess.run(["codesign", "--force", "--sign", "-", str(item)], check=True)
PY
codesign --force --sign - "$APP"

echo "==> Validating bundle before packaging..."
plutil -lint "$APP/Contents/Info.plist"
[[ "$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")" == "$APP_VERSION" ]] \
  || fail "App version does not match VERSION"
[[ "$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")" == "$APP_BUILD_NUMBER" ]] \
  || fail "App build number does not match BUILD_NUMBER"
lipo -info "$EXE"
codesign --verify --deep --strict --verbose=4 "$APP"

python3 - "$EXE" "$FRAMEWORKS" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

exe = Path(sys.argv[1])
frameworks = Path(sys.argv[2])
load = subprocess.check_output(["otool", "-l", str(exe)], text=True)
rpaths = []
for line in load.splitlines():
    match = re.match(r"\s*path (.+) \(offset \d+\)", line)
    if match:
        rpaths.append(match.group(1))

bad_rpaths = [
    rpath
    for rpath in rpaths
    if rpath.startswith("/Users/") or rpath.startswith("/Applications/Xcode")
]
if bad_rpaths:
    raise SystemExit(f"found build-machine absolute rpath: {bad_rpaths}")

if "@executable_path/../Frameworks" not in rpaths:
    raise SystemExit("missing bundle-relative Frameworks rpath")

required_architectures = {"arm64", "x86_64"}
main_architectures = set(
    subprocess.check_output(["lipo", "-archs", str(exe)], text=True).split()
)
if main_architectures != required_architectures:
    raise SystemExit(f"main executable architectures are {main_architectures}")

for item in frameworks.rglob("*"):
    if not item.is_file():
        continue
    result = subprocess.run(
        ["lipo", "-archs", str(item)], capture_output=True, text=True
    )
    if result.returncode != 0:
        continue
    architectures = set(result.stdout.split())
    if not required_architectures.issubset(architectures):
        raise SystemExit(f"runtime library is not Universal 2: {item}")

print("universal2_and_rpath_validation=ok")
PY

"$SCRIPT_DIR/create-dmg.sh" "$APP" "$OUT_ROOT/TESTING.md" "$DMG" "$APP_VERSION"

echo
echo "==> Gatekeeper assessment (non-Developer-ID package may be rejected; this is expected)"
if spctl --assess --type execute --verbose=4 "$APP"; then
  echo "spctl=accepted"
else
  echo "spctl=not-accepted (expected for controlled ad-hoc test package)"
fi

echo
echo "==> Removing temporary app staging directory..."
rm -rf "$OUT_ROOT"

echo
echo "Completed."
echo "DMG: $DMG"
echo "SHA-256 (DMG):"
shasum -a 256 "$DMG"
