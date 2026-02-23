#!/bin/bash
# wallzz - calm gradient/abstract wallpaper setter for macOS
# Sources: Wallhaven (tag-based, no auth), Minimalistic Wallpaper Collection

CACHE_DIR="$HOME/.cache/wallzz"
mkdir -p "$CACHE_DIR"

# Screen resolution
RES=$(system_profiler SPDisplaysDataType 2>/dev/null | grep Resolution | head -1 | awk '{print $2"x"$4}')
WIDTH=$(echo "$RES" | cut -dx -f1)
HEIGHT=$(echo "$RES" | cut -dx -f2)
[[ -z "$WIDTH" || "$WIDTH" -lt 1000 ]] && WIDTH=2560 && HEIGHT=1440

set_wallpaper() {
  local file="$1"
  file "$file" | grep -qiE 'image|JPEG|PNG|bitmap' || return 1
  osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$file\"" 2>/dev/null
}

# ── Wallhaven: curated tags, calm colors, sorted by community favorites ──
# Tag 32380 = "soft gradient" (145 results, almost all clean macOS-style blurs)
# Tag 2102  = "gradient" (2600+ results, broader pool)
# Calm colors from Wallhaven's palette
CALM_COLORS=("0099cc" "66cccc" "0066cc" "333399" "663399" "669900" "999999" "424153")

fetch_wallhaven() {
  local color="${CALM_COLORS[$((RANDOM % ${#CALM_COLORS[@]}))]}"
  local queries=(
    # Soft gradient — the gold mine, macOS-style blurs
    "id:32380"
    "id:32380"
    "id:32380"
    # Gradient + color filter for variety
    "id:2102&colors=${color}"
    "id:2102&colors=${color}"
    # Soft gradient + color
    "id:32380&colors=${color}"
  )

  local query="${queries[$((RANDOM % ${#queries[@]}))]}"
  local base_q=$(echo "$query" | cut -d'&' -f1)
  local extra=$(echo "$query" | grep -o '&.*' || true)

  local url="https://wallhaven.cc/api/v1/search?q=${base_q}&categories=100&purity=100&sorting=random&atleast=1920x1080&ratios=16x9,16x10${extra}"

  local json=$(curl -sf --max-time 10 "$url")
  [[ -z "$json" ]] && return 1

  local img_url=$(echo "$json" | python3 -c "
import json, sys, random
try:
    walls = json.load(sys.stdin).get('data', [])
    if walls: print(random.choice(walls)['path'])
except: pass
" 2>/dev/null)
  [[ -z "$img_url" ]] && return 1

  local outfile="$CACHE_DIR/wall.${img_url##*.}"
  curl -sf --max-time 15 -o "$outfile" "$img_url" || return 1
  echo "$outfile"
}

# ── Fallback: Minimalistic Wallpaper Collection (curated, always clean) ──
fetch_minimal() {
  local outfile="$CACHE_DIR/wall_minimal.png"
  curl -sfL --max-time 15 -o "$outfile" "https://minimalistic-wallpaper.demolab.com/?random=$RANDOM" || return 1
  local size=$(stat -f%z "$outfile" 2>/dev/null || stat -c%s "$outfile" 2>/dev/null)
  [[ "$size" -lt 10000 ]] && return 1
  echo "$outfile"
}

# ── Main ──
echo "wallzz — fetching..."

for attempt in 1 2 3; do
  file=$(fetch_wallhaven 2>/dev/null)
  if [[ -n "$file" && -f "$file" ]]; then
    set_wallpaper "$file" && echo "Done." && exit 0
  fi
done

file=$(fetch_minimal 2>/dev/null)
if [[ -n "$file" && -f "$file" ]]; then
  set_wallpaper "$file" && echo "Done. (minimal)" && exit 0
fi

echo "Failed — check connection."
exit 1
