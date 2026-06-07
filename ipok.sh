#!/usr/bin/env bash
#
# IPOK CLI — terminal IP purity / risk / AI-availability check
# Powered by https://ipok.io  (free, no-auth API)
#
# Usage:
#   bash <(curl -sL https://raw.githubusercontent.com/szp2005/ipok-cli/main/ipok.sh)          # check this server
#   bash <(curl -sL https://raw.githubusercontent.com/szp2005/ipok-cli/main/ipok.sh) 1.1.1.1   # check an IP
#
# Env:
#   IPOK_API   override API base (default https://ipok.io)
#
set -euo pipefail

API="${IPOK_API:-https://ipok.io}"
IP="${1:-}"
URL="$API/api/ip"
[ -n "$IP" ] && URL="$URL?ip=$IP"

command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required"; exit 1; }

JSON="$(curl -fsSL --max-time 25 "$URL")" || { echo "IPOK: request failed ($URL)"; exit 1; }

printf '%s' "$JSON" | python3 -c '
import json, sys
R="\033[0m"; DIM="\033[2m"; B="\033[1m"
GREEN="\033[32m"; YEL="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; GRAY="\033[90m"
try:
    d = json.load(sys.stdin)
except Exception:
    print("IPOK: bad response"); sys.exit(1)
g = d.get("geo", {})
risk = d.get("risk", 0)
bc = GREEN if risk < 50 else (YEL if risk < 70 else RED)
band = "Pristine" if risk < 15 else ("Clean" if risk < 50 else ("Caution" if risk < 70 else "High risk"))
def row(k, v):
    print("  " + GRAY + k.ljust(14) + R + " " + v)
print()
print("  " + CYAN + "IPOK" + R + GRAY + "  ip check  " + R + DIM + "ipok.io" + R)
print("  " + GRAY + ("-" * 46) + R)
row("IP", B + str(g.get("ip", "-")) + R + GRAY + "  IPv" + str(g.get("version", "?")) + R)
loc = " / ".join([x for x in [g.get("country"), g.get("city")] if x]) or "-"
row("Location", loc)
row("ASN", str(g.get("asn", "-")) + "  " + str(g.get("asName") or g.get("isp") or ""))
row("Type", str(d.get("ipType", "-")) + GRAY + "   native: " + str(d.get("nativeType", "-")) + R)
row("Risk", bc + str(risk) + "/100  " + band + R)
sig = d.get("signals", [])
if sig:
    row("Signals", YEL + ", ".join(sig) + R)
svc = d.get("services", [])
if svc:
    parts = []
    for s in svc:
        st = s.get("status")
        mark = GREEN + "OK" + R if st == "available" else (RED + "NO" + R if st == "blocked" else GRAY + "?" + R)
        parts.append(str(s.get("name")) + ":" + mark)
    row("AI", "  ".join(parts))
sc = d.get("scenarios", [])
if sc:
    parts = []
    for s in sc:
        stars = "*" * int(s.get("stars", 0))
        parts.append(str(s.get("key")) + " " + YEL + stars.ljust(5) + R)
    row("Use-case", "  ".join(parts))
srcs = [s for s in d.get("sources", []) if s.get("ok")]
if srcs:
    row("Sources", DIM + ", ".join(str(s.get("source")) + "=" + str(s.get("risk", "-")) for s in srcs) + R)
print("  " + GRAY + ("-" * 46) + R)
ipv = g.get("ip", "")
link = ("https://ipok.io/?ip=" + ipv) if ipv else "https://ipok.io"
print("  " + CYAN + "full report:  " + link + R)
print()
'
