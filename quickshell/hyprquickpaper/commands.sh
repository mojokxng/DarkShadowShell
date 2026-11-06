#!/usr/bin/env bash
# Replace "random" with: fade, wipe, grow, outer, wave, center, any, random

# commands.sh PICTURE [MONITOR [keep-colors]]: every monitor, or only MONITOR (awww -o). keep-colors: a monitor
# that is not the main one, so the colors and hyprquickpaper-current stay with the main monitor's wallpaper
img="$1"
out="${2:-}"
[[ -f "$img" ]] || { echo "commands.sh: not a file: $img" >&2; exit 1; }

awww img "$img" -t random --transition-duration 1 ${out:+-o "$out"}
[ "${3:-}" = "keep-colors" ] && exit 0

src="$HOME/.cache/quickshell/thumbs/$(basename "$img")"
[[ -f "$src" ]] || src="$img"

sat=$(convert -define jpeg:size=200x200 "$src" -resize 100x100! -colorspace HSL -channel G -separate +channel -format "%[fx:mean*100]" info:)
lum=$(convert -define jpeg:size=200x200 "$src" -resize 100x100! -colorspace Gray -format "%[fx:mean*100]" info:)

mode="$(cat "$HOME/.config/rice/color-mode" 2>/dev/null)"
scheme=""
case "$mode" in
  grey) sat=0; lum=50 ;;
  navy) sat=0; lum=0 ;;
  ""|auto) ;;
  *) scheme="$("$HOME/.local/bin/rice-colors" scheme "$mode" 2>/dev/null)" ;;
esac

if [ -n "$scheme" ]; then
  # named color scheme from Settings > Home > Colors: "<matugen type> <seed> <workspace marker>"
  read -r stype seed ws <<<"$scheme"
  cmd=(matugen color hex "$seed" --type "$stype" -q)
elif awk "BEGIN{exit !($sat < 12)}"; then
  ws='#8a8a8a'
  if awk "BEGIN{exit !($lum < 12)}"; then
    cmd=(matugen color hex "#1a2a5e" -q)
  else
    cmd=(matugen image "$src" --type scheme-monochrome --source-color-index 0 -q)
  fi
else
  ws='@on_accent'
  cmd=(matugen image "$src" --source-color-index 0 -q)
fi

printf '@define-color ws_active %s;\n' "$ws" > "$HOME/.config/waybar/ws-active.css"
"${cmd[@]}"

mkdir -p "$HOME/.cache"
echo "$img" > "$HOME/.cache/hyprquickpaper-current"

# recolor notifications and the lock screen (Shadow's Shell)
"$HOME/.local/bin/rice-colors" refresh >/dev/null 2>&1 &
