"""IPOK CLI — terminal IP purity / risk / AI-availability check.

Powered by https://ipok.io  (free, no-auth API). Zero third-party deps.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

__version__ = "0.1.0"

API_DEFAULT = "https://ipok.io"
TIMEOUT = 25

# ---- ANSI helpers -----------------------------------------------------------
_NO_COLOR = bool(os.environ.get("NO_COLOR")) or not sys.stdout.isatty()


class C:
    R = "" if _NO_COLOR else "\033[0m"
    DIM = "" if _NO_COLOR else "\033[2m"
    B = "" if _NO_COLOR else "\033[1m"
    GREEN = "" if _NO_COLOR else "\033[32m"
    YEL = "" if _NO_COLOR else "\033[33m"
    RED = "" if _NO_COLOR else "\033[31m"
    CYAN = "" if _NO_COLOR else "\033[36m"
    GRAY = "" if _NO_COLOR else "\033[90m"


HELP = f"""IPOK CLI v{__version__} — IP purity / risk / AI-availability check (ipok.io)

USAGE:
  ipok                 check this machine's egress IP
  ipok <ip>            check a specific IP (e.g. ipok 1.1.1.1)
  ipok --json [ip]     print raw JSON from the API
  ipok -h, --help      show this help
  ipok -v, --version   show version

ENV:
  IPOK_API   override API base (default https://ipok.io)
  NO_COLOR   disable colored output

Data by https://ipok.io — free, no API key required.
"""


def fetch(ip: str | None, api: str) -> dict:
    url = api.rstrip("/") + "/api/ip"
    if ip:
        url += "?" + urllib.parse.urlencode({"ip": ip})
    req = urllib.request.Request(url, headers={"User-Agent": f"ipok-cli/{__version__}"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:  # noqa: S310 (trusted host)
        return json.load(resp)


def _band(risk: int) -> tuple[str, str]:
    if risk < 15:
        return C.GREEN, "Pristine"
    if risk < 50:
        return C.GREEN, "Clean"
    if risk < 70:
        return C.YEL, "Caution"
    return C.RED, "High risk"


def render(d: dict) -> str:
    g = d.get("geo", {}) or {}
    risk = int(d.get("risk", 0) or 0)
    bc, band = _band(risk)
    out: list[str] = []

    def row(k: str, v: str) -> None:
        out.append("  " + C.GRAY + k.ljust(14) + C.R + " " + v)

    out.append("")
    out.append("  " + C.CYAN + "IPOK" + C.R + C.GRAY + "  ip check  " + C.R + C.DIM + "ipok.io" + C.R)
    out.append("  " + C.GRAY + ("-" * 46) + C.R)
    row("IP", C.B + str(g.get("ip", "-")) + C.R + C.GRAY + "  IPv" + str(g.get("version", "?")) + C.R)
    loc = " / ".join([x for x in [g.get("country"), g.get("city")] if x]) or "-"
    row("Location", loc)
    row("ASN", str(g.get("asn", "-")) + "  " + str(g.get("asName") or g.get("isp") or ""))
    row("Type", str(d.get("ipType", "-")) + C.GRAY + "   native: " + str(d.get("nativeType", "-")) + C.R)
    row("Risk", bc + str(risk) + "/100  " + band + C.R)

    sig = d.get("signals") or []
    if sig:
        row("Signals", C.YEL + ", ".join(map(str, sig)) + C.R)

    svc = d.get("services") or []
    if svc:
        parts = []
        for s in svc:
            st = s.get("status")
            mark = (
                C.GREEN + "OK" + C.R if st == "available"
                else (C.RED + "NO" + C.R if st == "blocked" else C.GRAY + "?" + C.R)
            )
            parts.append(str(s.get("name")) + ":" + mark)
        row("AI", "  ".join(parts))

    sc = d.get("scenarios") or []
    if sc:
        parts = []
        for s in sc[:6]:
            stars = "*" * int(s.get("stars", 0) or 0)
            parts.append(str(s.get("key")) + " " + C.YEL + stars.ljust(5) + C.R)
        row("Use-case", "  ".join(parts))

    srcs = [s for s in (d.get("sources") or []) if s.get("ok")]
    if srcs:
        row("Sources", C.DIM + ", ".join(
            str(s.get("source")) + "=" + str(s.get("risk", "-")) for s in srcs) + C.R)

    out.append("  " + C.GRAY + ("-" * 46) + C.R)
    ipv = g.get("ip", "")
    link = ("https://ipok.io/?ip=" + str(ipv)) if ipv else "https://ipok.io"
    out.append("  " + C.CYAN + "full report:  " + link + C.R)
    out.append("")
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    as_json = False
    ip: str | None = None

    for a in args:
        if a in ("-h", "--help"):
            print(HELP)
            return 0
        if a in ("-v", "--version"):
            print(f"ipok {__version__}")
            return 0
        if a == "--json":
            as_json = True
        elif a.startswith("-"):
            sys.stderr.write(f"ipok: unknown option {a}\n")
            return 2
        else:
            ip = a

    api = os.environ.get("IPOK_API", API_DEFAULT)
    try:
        data = fetch(ip, api)
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"IPOK: request failed (HTTP {e.code})\n")
        return 1
    except (urllib.error.URLError, TimeoutError) as e:
        sys.stderr.write(f"IPOK: request failed ({e})\n")
        return 1
    except Exception as e:  # noqa: BLE001
        sys.stderr.write(f"IPOK: {e}\n")
        return 1

    if as_json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(render(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
