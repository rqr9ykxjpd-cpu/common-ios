#!/bin/sh
# Bond App Store 6.9" ham kareleri. iPhone 17 Pro Max, örnek veri.
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SIM="${SIM:-CB8BEE12-FE13-4664-8427-876193E59871}"
BUNDLE="com.campus.social"
RAW="$ROOT/store/screenshots/raw"
mkdir -p "$RAW"

xcrun simctl boot "$SIM" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$SIM"
xcrun simctl bootstatus "$SIM" -b

status_bar() {
    xcrun simctl status_bar "$SIM" override \
        --time "9:41" \
        --dataNetwork wifi \
        --wifiMode active \
        --wifiBars 3 \
        --cellularMode active \
        --cellularBars 4 \
        --operatorName '' \
        --batteryState discharging \
        --batteryLevel 100
}

xcrun simctl ui "$SIM" appearance light
xcrun simctl privacy "$SIM" grant notifications "$BUNDLE" || true
status_bar

APP="$(find /tmp/BondSimDD/Build/Products -name Bond.app -path '*iphonesimulator*' 2>/dev/null | head -1)"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "Bond.app yok; önce simülatör derlemesi lazım." >&2
    exit 1
fi
xcrun simctl install "$SIM" "$APP"

# İlk açılış yavaş (asset kopyası, JIT). Isındır, asıl kareleri sonra çek.
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$SIM" "$BUNDLE" -sample -tab feed
sleep 6
status_bar

shot() {
    name="$1"
    wait="$2"
    shift 2
    xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
    sleep 0.5
    xcrun simctl launch "$SIM" "$BUNDLE" "$@"
    sleep "$wait"
    status_bar
    xcrun simctl io "$SIM" screenshot "$RAW/${name}.png"
    echo "çekildi $name"
}

shot 01-feed 6.5 -sample -tab feed
shot 02-discover 5.0 -sample -tab discover
shot 03-story 6.0 -sample -story Ece
shot 04-places 6.0 -sample -places
shot 05-chats 6.0 -sample -tab discover -chats
shot 06-profile 5.5 -sample -profile Ece

echo "ham kareler: $RAW"
