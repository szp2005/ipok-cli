#!/usr/bin/env bash
#
# IPOK media unlock — test streaming / AI region unlock from THIS server's exit IP
# Powered by https://ipok.io
#
# Usage:
#   bash <(curl -sL https://raw.githubusercontent.com/szp2005/ipok-cli/main/media.sh)
#
# Runs on the VPS/server you want to test — results reflect the server's outbound IP.
# Note: streaming providers change endpoints often; treat results as best-effort.
#
set -uo pipefail

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123 Safari/537.36"
R="\033[0m"; B="\033[1m"; GREEN="\033[32m"; RED="\033[31m"; YEL="\033[33m"; CYAN="\033[36m"; GRAY="\033[90m"
get() { curl -s -m 12 -H "User-Agent: $UA" "$@"; }
code() { curl -s -o /dev/null -w "%{http_code}" -m 12 -H "User-Agent: $UA" "$@"; }
ok()   { printf "  %-18s ${GREEN}%s${R}\n" "$1" "$2"; }
bad()  { printf "  %-18s ${RED}%s${R}\n"   "$1" "$2"; }
warn() { printf "  %-18s ${YEL}%s${R}\n"   "$1" "$2"; }
dim()  { printf "  %-18s ${GRAY}%s${R}\n"  "$1" "$2"; }

echo
printf "  ${CYAN}IPOK${R}${GRAY}  media unlock  ${R}${GRAY}ipok.io${R}\n"
# exit IP line from IPOK
EGRESS=$(get "https://ipok.io/api/ip" | grep -o '"ip":"[^"]*"' | head -1 | sed 's/.*:"//;s/"//')
[ -n "${EGRESS:-}" ] && dim "exit IP" "$EGRESS"
printf "  ${GRAY}----------------------------------------------${R}\n"

# --- Netflix ---
netflix() {
  local c1 c2 region
  c1=$(code "https://www.netflix.com/title/81280792")   # region-restricted title
  c2=$(code "https://www.netflix.com/title/80018499")   # widely available title
  if [ "$c1" = "000" ] && [ "$c2" = "000" ]; then bad "Netflix" "check failed"; return; fi
  region=$(get "https://www.netflix.com/title/80018499" | grep -o '"requestCountry":{"id":"[A-Z]*"' | grep -o '[A-Z]\{2\}' | head -1)
  if [ "$c1" = "404" ] && [ "$c2" = "404" ]; then bad "Netflix" "blocked";
  elif [ "$c1" = "404" ]; then warn "Netflix" "originals only ${region:+($region)}";
  else ok "Netflix" "full unlock ${region:+($region)}"; fi
}

# --- ChatGPT (region support via Cloudflare trace) ---
chatgpt() {
  local loc blocked="CN HK RU KP IR CU SY"
  loc=$(get "https://chat.openai.com/cdn-cgi/trace" | grep -o 'loc=[A-Z]*' | cut -d= -f2)
  [ -z "$loc" ] && { bad "ChatGPT" "check failed"; return; }
  if echo " $blocked " | grep -q " $loc "; then bad "ChatGPT" "not supported ($loc)";
  else ok "ChatGPT" "supported ($loc)"; fi
}

# --- YouTube Premium region ---
youtube() {
  local html region
  html=$(get "https://www.youtube.com/premium")
  region=$(echo "$html" | grep -o '"countryCode":"[A-Z]*"' | head -1 | grep -o '[A-Z]\{2\}')
  if echo "$html" | grep -q "Premium is not available"; then bad "YouTube Premium" "not available ${region:+($region)}";
  elif [ -n "$region" ]; then ok "YouTube Premium" "available ($region)";
  else dim "YouTube Premium" "unknown"; fi
}

# --- TikTok region ---
tiktok() {
  local region
  region=$(get "https://www.tiktok.com/" | grep -o '"region":"[A-Z]*"' | head -1 | grep -o '[A-Z]\{2\}')
  if [ -n "$region" ]; then ok "TikTok" "region $region"; else dim "TikTok" "unknown"; fi
}

netflix
chatgpt
youtube
tiktok

printf "  ${GRAY}----------------------------------------------${R}\n"
printf "  ${CYAN}full IP report:  https://ipok.io${R}\n"
echo
