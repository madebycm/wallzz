#!/bin/bash
# wallzz - calm gradient/abstract wallpaper setter for macOS
# Batch-fetches 20 curated wallpapers, cycles through them

CACHE_DIR="$HOME/.cache/wallzz"
FAV_DIR="$CACHE_DIR/favorites"
INDEX_FILE="$CACHE_DIR/.index"
FAV_INDEX="$CACHE_DIR/.fav_index"
mkdir -p "$CACHE_DIR" "$FAV_DIR"

# ── Favorites ──
if [[ "$1" == "fav" ]]; then
  if [[ "$2" == "list" ]]; then
    count=$(find "$FAV_DIR" -type f \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | wc -l | tr -d ' ')
    echo "wallzz — $count favorites"
    open "$FAV_DIR"
    exit 0
  fi
  if [[ "$2" == "next" ]]; then
    favs=()
    while IFS= read -r f; do favs+=("$f"); done < <(find "$FAV_DIR" -type f \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | sort)
    if [[ ${#favs[@]} -eq 0 ]]; then
      echo "wallzz — no favorites yet. Use 'wz fav' to save one."
      exit 1
    fi
    idx=0
    [[ -f "$FAV_INDEX" ]] && idx=$(cat "$FAV_INDEX")
    [[ $idx -ge ${#favs[@]} ]] && idx=0
    file="${favs[$idx]}"
    osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$file\"" 2>/dev/null
    echo "wallzz fav ($((idx+1))/${#favs[@]})"
    echo "$(( (idx+1) % ${#favs[@]} ))" > "$FAV_INDEX"
    exit 0
  fi
  # Save current wallpaper as favorite
  current_file=$(osascript -e 'tell application "System Events" to get picture of current desktop' 2>/dev/null)
  if [[ -n "$current_file" && -f "$current_file" ]]; then
    ts=$(date +%s)
    ext="${current_file##*.}"
    cp "$current_file" "$FAV_DIR/fav_${ts}.${ext}"
    count=$(find "$FAV_DIR" -type f \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | wc -l | tr -d ' ')
    echo "wallzz — saved to favorites ($count total)"
  else
    echo "wallzz — couldn't detect current wallpaper"
  fi
  exit 0
fi


# ── Screen resolution ──
RES=$(system_profiler SPDisplaysDataType 2>/dev/null | grep Resolution | head -1 | awk '{print $2"x"$4}')
WIDTH=$(echo "$RES" | cut -dx -f1)
HEIGHT=$(echo "$RES" | cut -dx -f2)
[[ -z "$WIDTH" || "$WIDTH" -lt 1000 ]] && WIDTH=2560 && HEIGHT=1440

BATCH_SIZE=20

set_wallpaper() {
  local file="$1"
  file "$file" | grep -qiE 'image|JPEG|PNG|bitmap' || return 1
  osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$file\"" 2>/dev/null
}

# ── Tag-based quality filter (rejects images with objects/people/text) ──
check_tags() {
  local wh_id="$1"
  curl -sf --max-time 5 "https://wallhaven.cc/api/v1/w/$wh_id" | python3 -c "
import json, sys
tags = [t['name'].strip().lower() for t in json.load(sys.stdin)['data'].get('tags', [])]
# Reject images with these EXACT tags (whole word match)
reject = {'car','cars','person','people','girl','boy','woman','man','text','typography',
          'logo','anime','military','aircraft','statue','animal','building','city','cities',
          'nvidia','band','music','movie','portrait','face','weapon','gun','sword','robot',
          'mecha','cat','dog','horse','pokemon','character','letter','number','word',
          'quote','sign','brand','advertisement','screenshot','video games','game'}
for t in tags:
    if t in reject:
        sys.exit(1)
print('ok')
" 2>/dev/null
}

# ── Fetch a fresh batch of wallpapers ──
fetch_batch() {
  echo "wallzz — fetching $BATCH_SIZE wallpapers..."
  rm -f "$CACHE_DIR"/wz_*.{jpg,png} "$INDEX_FILE" 2>/dev/null

  local count=0
  local seen_ids=""
  local CALM_COLORS=("0099cc" "66cccc" "0066cc" "333399" "663399" "669900" "999999" "424153")

  while [[ $count -lt $BATCH_SIZE ]]; do
    local color="${CALM_COLORS[$((RANDOM % ${#CALM_COLORS[@]}))]}"
    local queries=(
      # Starkiteckt artist — 193 guaranteed-clean gradients
      "id:24174"
      "id:24174"
      # Soft gradient tag
      "id:32380"
      "id:32380"
      # Soft gradient + color
      "id:32380&colors=${color}"
    )
    local query="${queries[$((RANDOM % ${#queries[@]}))]}"
    local base_q=$(echo "$query" | cut -d'&' -f1)
    local extra=$(echo "$query" | grep -o '&.*' || true)

    local url="https://wallhaven.cc/api/v1/search?q=${base_q}&categories=100&purity=100&sorting=random&atleast=1920x1080&ratios=16x9,16x10${extra}"

    local json=$(curl -sf --max-time 10 "$url")
    [[ -z "$json" ]] && continue

    # Process each result
    while IFS='|' read -r wh_id img_url; do
      [[ -z "$img_url" ]] && continue
      [[ $count -ge $BATCH_SIZE ]] && break

      # Skip already seen
      echo "$seen_ids" | grep -qF "$wh_id" && continue
      seen_ids="$seen_ids $wh_id"

      # Tag check (skip for Starkiteckt — always clean)
      if [[ "$query" != *"id:24174"* ]]; then
        check_tags "$wh_id" || continue
      fi

      local ext="${img_url##*.}"
      local num=$(printf "%02d" $count)
      local outfile="$CACHE_DIR/wz_${num}.${ext}"

      if curl -sf --max-time 12 -o "$outfile" "$img_url"; then
        if file "$outfile" | grep -qiE 'image|JPEG|PNG|bitmap'; then
          ((count++))
          printf "\r  %d/%d" "$count" "$BATCH_SIZE"
        else
          rm -f "$outfile"
        fi
      fi
    done < <(echo "$json" | python3 -c "
import json, sys
for w in json.load(sys.stdin).get('data', []):
    print(f'{w[\"id\"]}|{w[\"path\"]}')
" 2>/dev/null)
  done

  echo ""
  echo "0" > "$INDEX_FILE"
}

# ── Main ──
wallpapers=()
while IFS= read -r f; do wallpapers+=("$f"); done < <(find "$CACHE_DIR" -maxdepth 1 -name 'wz_*' -type f 2>/dev/null | sort)
index=0
[[ -f "$INDEX_FILE" ]] && index=$(cat "$INDEX_FILE")

if [[ ${#wallpapers[@]} -eq 0 || $index -ge ${#wallpapers[@]} ]]; then
  fetch_batch
  wallpapers=()
  while IFS= read -r f; do wallpapers+=("$f"); done < <(find "$CACHE_DIR" -maxdepth 1 -name 'wz_*' -type f 2>/dev/null | sort)
  index=0
fi

current="${wallpapers[$index]}"
next=$((index + 1))

if [[ -n "$current" && -f "$current" ]]; then
  if set_wallpaper "$current"; then
    echo "$next" > "$INDEX_FILE"
    if [[ $next -ge ${#wallpapers[@]} ]]; then
      echo "wallzz ($((index+1))/${#wallpapers[@]}) — next run fetches fresh batch"
    else
      echo "wallzz ($((index+1))/${#wallpapers[@]})"
    fi
    exit 0
  fi
fi

echo "Failed — run again to refetch."
rm -f "$INDEX_FILE"
exit 1
