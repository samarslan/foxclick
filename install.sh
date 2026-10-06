#!/usr/bin/env bash
# foxclick installer.
#
#   ./install.sh                 install + register Meta+X (KDE)
#   FOXCLICK_KEY="Meta+Shift+C" ./install.sh
#   FOXCLICK_KEY=none ./install.sh   skip the global shortcut
#   FOXCLICK_CAPTURE_KEY=Meta+H FOXCLICK_CLICK_KEY=Meta+C ./install.sh
#
# Everything lands under $HOME; no root needed.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/foxclick"
app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
key="${FOXCLICK_KEY:-Meta+X}"
capture_key="${FOXCLICK_CAPTURE_KEY:-Meta+H}"
click_key="${FOXCLICK_CLICK_KEY:-Meta+C}"

echo "installing foxclick"
mkdir -p "$bin_dir" "$cfg_dir" "$app_dir"

install -m 755 "$src/foxclick" "$bin_dir/foxclick"
echo "  $bin_dir/foxclick"

if [ -e "$cfg_dir/config" ]; then
    echo "  $cfg_dir/config  (kept - already exists)"
else
    install -m 644 "$src/config.example" "$cfg_dir/config"
    echo "  $cfg_dir/config"
fi

write_shortcut() {
    local file="$1" command="$2" name="$3"
    cat > "$app_dir/$file" <<EOF
[Desktop Entry]
Exec=$bin_dir/foxclick $command
Name=$name
NoDisplay=true
StartupNotify=false
Type=Application
X-KDE-GlobalAccel-CommandShortcut=true
EOF
    echo "  $app_dir/$file"
}

write_shortcut foxclick.desktop toggle "Foxclick Toggle"
write_shortcut foxclick-capture.desktop capture "Foxclick Capture Position"
write_shortcut foxclick-click.desktop click "Foxclick Click Saved Position"

case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) echo "  note: $bin_dir is not on your PATH" ;;
esac

# ---- KDE global shortcuts (best effort) ----
if ! command -v kwriteconfig6 >/dev/null 2>&1; then
    echo "not KDE Plasma - skipping automatic global shortcut."
    echo "Bind '$bin_dir/foxclick toggle', '$bin_dir/foxclick capture', and"
    echo "'$bin_dir/foxclick click' to keys in your compositor/DE config."
    echo "See the 'Global shortcut' section of the README for per-environment examples."
    exit 0
fi
qt_keycode() {
    local spec="$1" total=0 part key
    IFS='+' read -ra parts <<< "$spec"
    for part in "${parts[@]}"; do
        case "${part,,}" in
            meta|super|win) total=$(( total + 0x10000000 )) ;;
            ctrl|control)   total=$(( total + 0x04000000 )) ;;
            alt)            total=$(( total + 0x08000000 )) ;;
            shift)          total=$(( total + 0x02000000 )) ;;
            f[1-9]|f1[0-9]) total=$(( total + 0x01000030 + ${part#[Ff]} - 1 )) ;;
            [a-z])          printf -v key '%d' "'${part^^}"; total=$(( total + key )) ;;
            [0-9])          printf -v key '%d' "'$part";      total=$(( total + key )) ;;
            *) echo "cannot parse key part: $part" >&2; return 1 ;;
        esac
    done
    echo "$total"
}

register_shortcut() {
    local file="$1" name="$2" shortcut="$3" code aid
    case "${shortcut,,}" in none) echo "global shortcut: $name skipped"; return 0 ;; esac
    kwriteconfig6 --file kglobalshortcutsrc --group services --group "$file" \
        --key _launch "$shortcut"
    code="$(qt_keycode "$shortcut" 2>/dev/null || true)"
    if [ -n "$code" ] && command -v gdbus >/dev/null 2>&1; then
        aid="['$file', '_launch', '$name', 'Launch']"
        gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
            --method org.kde.KGlobalAccel.doRegister "$aid" >/dev/null 2>&1 || true
        if gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
            --method org.kde.KGlobalAccel.setShortcut "$aid" "[$code]" 2 >/dev/null 2>&1; then
            echo "global shortcut: $shortcut for $name (active now)"
            return 0
        fi
    fi
    echo "global shortcut: $shortcut for $name (written; active after next login)"
}

register_shortcut foxclick.desktop "Foxclick Toggle" "$key"
register_shortcut foxclick-capture.desktop "Foxclick Capture Position" "$capture_key"
register_shortcut foxclick-click.desktop "Foxclick Click Saved Position" "$click_key"
