#!/usr/bin/env bash
set -euo pipefail

kind="${1:-sink}"                      # sink = вывод, source = ввод
[ "$kind" = "sink" ] || [ "$kind" = "source" ] || { echo "arg sink|source"; exit 2; }

get_default() { pactl get-default-"$kind"; }
set_default()  { pactl set-default-"$kind" "$1"; }
list_all()     { pactl list short "${kind}s" | awk '{print $2}'; }
is_muted()     { pactl get-"$kind"-mute @DEFAULT_"${kind^^}"@ | awk '{print $2}'; }
get_vol()      { pactl get-"$kind"-volume @DEFAULT_"${kind^^}"@ | awk -F'/' 'NR==1{gsub(/ /,""); print $2}'; }
toggle_mute() { pactl set-"$kind"-mute @DEFAULT_"${kind^^}"@ toggle; }
vol_up() { pactl set-"$kind"-volume @DEFAULT_"${kind^^}"@ +5%; }
vol_down() { pactl set-"$kind"-volume @DEFAULT_"${kind^^}"@ -5%; }

get_desc() {
  pactl list "${kind}s" | grep -A 10 "Name: $(get_default)" | grep "Description:" | sed 's/.*Description: //'
}

cycle_next() {
  cur="$(get_default)"
  mapfile -t arr < <(list_all)
  [ "${#arr[@]}" -gt 0 ] || exit 0

  for i in "${!arr[@]}"; do
    if [[ "${arr[$i]}" == "$cur" ]]; then
      nxt="${arr[$(( (i+1) % ${#arr[@]} ))]}"
      set_default "$nxt"

      if [ "$kind" = "sink" ]; then
        for si in $(pactl list short sink-inputs | awk '{print $1}'); do
          pactl move-sink-input "$si" "$nxt"
        done
      else
        for so in $(pactl list short source-outputs | awk '{print $1}'); do
          pactl move-source-output "$so" "$nxt"
        done
      fi
      break
    fi
  done
}

case "${BLOCK_BUTTON:-0}" in
  1) toggle_mute ;;
  2) cycle_next ;;
  3) pavucontrol &>/dev/null & ;;
  4) vol_up ;;
  5) vol_down ;;
esac

muted="$(is_muted || echo 'no')"
vol="$(get_vol || echo '0%')"
desc="$(get_desc)"; [ -n "${desc:-}" ] || desc="$(get_default)"

if [ "$kind" = "sink" ]; then
  icon_muted=" "
  icon_up=" "
else
  icon_muted=" "
  icon_up=""
fi

output="$([ "$muted" = "yes" ] && echo "$icon_muted $desc [muted]" || echo "$icon_up $desc $vol")"
color="$([ "$muted" = "yes" ] && echo "#FF5555" || echo "#A3BE8C")"

echo "$output"
echo "$output"  
echo "$color"
