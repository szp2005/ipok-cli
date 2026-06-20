#!/usr/bin/env node
/*
 * IPOK CLI — terminal IP purity / risk / AI-availability check.
 * Powered by https://ipok.io (free, no-auth API). Zero dependencies (Node 18+).
 */
"use strict";

const VERSION = "0.1.0";
const API_DEFAULT = "https://ipok.io";
const TIMEOUT = 25000;

const noColor = !!process.env.NO_COLOR || !process.stdout.isTTY;
const c = noColor
  ? { R: "", DIM: "", B: "", GREEN: "", YEL: "", RED: "", CYAN: "", GRAY: "" }
  : {
      R: "\x1b[0m", DIM: "\x1b[2m", B: "\x1b[1m",
      GREEN: "\x1b[32m", YEL: "\x1b[33m", RED: "\x1b[31m",
      CYAN: "\x1b[36m", GRAY: "\x1b[90m",
    };

const HELP = `IPOK CLI v${VERSION} — IP purity / risk / AI-availability check (ipok.io)

USAGE:
  ipok                 check this machine's egress IP
  ipok <ip>            check a specific IP (e.g. ipok 1.1.1.1)
  ipok --json [ip]     print raw JSON from the API
  ipok -h, --help      show this help
  ipok -v, --version   show version

ENV:
  IPOK_API   override API base (default https://ipok.io)
  NO_COLOR   disable colored output

Data by https://ipok.io — free, no API key required.`;

function pad(s, n) {
  s = String(s);
  return s.length >= n ? s : s + " ".repeat(n - s.length);
}

function band(risk) {
  if (risk < 15) return [c.GREEN, "Pristine"];
  if (risk < 50) return [c.GREEN, "Clean"];
  if (risk < 70) return [c.YEL, "Caution"];
  return [c.RED, "High risk"];
}

function render(d) {
  const g = d.geo || {};
  const risk = parseInt(d.risk, 10) || 0;
  const [bc, label] = band(risk);
  const out = [];
  const row = (k, v) => out.push("  " + c.GRAY + pad(k, 14) + c.R + " " + v);

  out.push("");
  out.push("  " + c.CYAN + "IPOK" + c.R + c.GRAY + "  ip check  " + c.R + c.DIM + "ipok.io" + c.R);
  out.push("  " + c.GRAY + "-".repeat(46) + c.R);
  row("IP", c.B + (g.ip ?? "-") + c.R + c.GRAY + "  IPv" + (g.version ?? "?") + c.R);
  const loc = [g.country, g.city].filter(Boolean).join(" / ") || "-";
  row("Location", loc);
  row("ASN", (g.asn ?? "-") + "  " + (g.asName || g.isp || ""));
  row("Type", (d.ipType ?? "-") + c.GRAY + "   native: " + (d.nativeType ?? "-") + c.R);
  row("Risk", bc + risk + "/100  " + label + c.R);

  if (Array.isArray(d.signals) && d.signals.length)
    row("Signals", c.YEL + d.signals.join(", ") + c.R);

  if (Array.isArray(d.services) && d.services.length) {
    const parts = d.services.map((s) => {
      const mark =
        s.status === "available" ? c.GREEN + "OK" + c.R
        : s.status === "blocked" ? c.RED + "NO" + c.R
        : c.GRAY + "?" + c.R;
      return s.name + ":" + mark;
    });
    row("AI", parts.join("  "));
  }

  if (Array.isArray(d.scenarios) && d.scenarios.length) {
    const parts = d.scenarios.slice(0, 6).map(
      (s) => s.key + " " + c.YEL + pad("*".repeat(s.stars || 0), 5) + c.R
    );
    row("Use-case", parts.join("  "));
  }

  const srcs = (d.sources || []).filter((s) => s.ok);
  if (srcs.length)
    row("Sources", c.DIM + srcs.map((s) => s.source + "=" + (s.risk ?? "-")).join(", ") + c.R);

  out.push("  " + c.GRAY + "-".repeat(46) + c.R);
  const link = g.ip ? "https://ipok.io/?ip=" + g.ip : "https://ipok.io";
  out.push("  " + c.CYAN + "full report:  " + link + c.R);
  out.push("");
  return out.join("\n");
}

async function fetchIp(ip, api) {
  let url = api.replace(/\/+$/, "") + "/api/ip";
  if (ip) url += "?ip=" + encodeURIComponent(ip);
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), TIMEOUT);
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "ipok-cli/" + VERSION },
      signal: ctrl.signal,
    });
    if (!res.ok) throw new Error("HTTP " + res.status);
    return await res.json();
  } finally {
    clearTimeout(t);
  }
}

async function main() {
  const args = process.argv.slice(2);
  let asJson = false;
  let ip = null;
  for (const a of args) {
    if (a === "-h" || a === "--help") { console.log(HELP); return 0; }
    if (a === "-v" || a === "--version") { console.log("ipok " + VERSION); return 0; }
    if (a === "--json") { asJson = true; }
    else if (a.startsWith("-")) { process.stderr.write("ipok: unknown option " + a + "\n"); return 2; }
    else { ip = a; }
  }

  const api = process.env.IPOK_API || API_DEFAULT;
  let data;
  try {
    data = await fetchIp(ip, api);
  } catch (e) {
    process.stderr.write("IPOK: request failed (" + (e && e.message ? e.message : e) + ")\n");
    return 1;
  }

  if (asJson) console.log(JSON.stringify(data, null, 2));
  else console.log(render(data));
  return 0;
}

main().then((code) => process.exit(code)).catch((e) => {
  process.stderr.write("IPOK: " + (e && e.message ? e.message : e) + "\n");
  process.exit(1);
});
