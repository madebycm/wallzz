#!/bin/bash
# wallzz - random gradient/abstract wallpaper fetcher for macOS
# Source: Wallhaven API (no auth required)

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

# Curated queries using Wallhaven's tag system
# Tag 2102 = "gradient" (curated, 1400+ results at 2560x1440+)
# Tag 32380 = "soft gradient" (102 results)
# Tag 24174 = "Starkiteckt" (gradient artist, 176 results)
# Color filters for variety
QUERIES=(
  "id:2102"                  # all gradients
  "id:2102"                  # weighted: gradients are the best source
  "id:32380"                 # soft gradients
  "id:24174"                 # Starkiteckt gradient art
  "id:2102&colors=0066cc"    # blue gradients
  "id:2102&colors=663399"    # purple gradients
  "id:2102&colors=996633"    # warm gradients
  "id:74&colors=0066cc"      # abstract blue
  "id:74&colors=cc6633"      # abstract warm
)

echo "wallzz — fetching..."

for attempt in 1 2 3; do
  query="${QUERIES[$((RANDOM % ${#QUERIES[@]}))]}"
  base_q=$(echo "$query" | cut -d'&' -f1)
  extra=$(echo "$query" | grep -o '&.*' || true)

  url="https://wallhaven.cc/api/v1/search?q=${base_q}&categories=100&purity=100&sorting=random&atleast=${WIDTH}x${HEIGHT}${extra}"

  json=$(curl -sf --max-time 10 "$url")
  [[ -z "$json" ]] && continue

  img_url=$(echo "$json" | python3 -c "
import json, sys, random
try:
    walls = json.load(sys.stdin).get('data', [])
    if walls: print(random.choice(walls)['path'])
except: pass
" 2>/dev/null)
  [[ -z "$img_url" ]] && continue

  outfile="$CACHE_DIR/wall.${img_url##*.}"
  curl -sf --max-time 15 -o "$outfile" "$img_url" || continue

  if set_wallpaper "$outfile"; then
    echo "Done."
    exit 0
  fi
done

echo "Failed — check connection."
exit 1
