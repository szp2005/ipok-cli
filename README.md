# IPOK CLI

> Terminal IP **purity / risk / AI-availability** check — powered by [ipok.io](https://ipok.io)

Check any IP's quality from your VPS or terminal in one line: risk score, residential vs datacenter, **native IP**, whether it can use **ChatGPT / Claude / Gemini**, use-case fit for **TikTok / e-commerce / social / AI**, and more.

一行命令测 IP 纯净度 / 风险值 / 能不能用 AI —— 由 [ipok.io](https://ipok.io) 提供数据。

> 🧩 Prefer a browser? Get the **[IPOK Chrome extension](https://chromewebstore.google.com/detail/jnbkfmgldcchpdgnegafakbcnmkdhiai)** — one click to check your current IP's purity. ·
> 想用浏览器？装 **[IPOK Chrome 插件](https://chromewebstore.google.com/detail/jnbkfmgldcchpdgnegafakbcnmkdhiai)**，一键查当前 IP 纯净度。

```
  IPOK  ip check  ipok.io
  ----------------------------------------------
  IP             1.1.1.1  IPv4
  Location       Australia / South Brisbane
  ASN            AS13335  CLOUDFLARENET
  Type           hosting   native: native
  Risk           55/100  Caution
  AI             ChatGPT:OK  Claude:OK  Gemini:OK
  Use-case       tiktok **    ecommerce **    social **    ai ****
  Sources        ip-api=55
  ----------------------------------------------
  full report:  https://ipok.io/?ip=1.1.1.1
```

## Quick start

Check this server's egress IP:

```bash
bash <(curl -sL https://raw.githubusercontent.com/szp2005/ipok-cli/main/ipok.sh)
```

Check a specific IP:

```bash
bash <(curl -sL https://raw.githubusercontent.com/szp2005/ipok-cli/main/ipok.sh) 1.1.1.1
```

Requirements: `curl` + `python3` (present on virtually all Linux servers).

## Streaming / AI unlock (run on the server)

Test what **this server's exit IP** can unlock — Netflix (full / originals-only / blocked + region), ChatGPT region support, YouTube Premium, TikTok:

```bash
bash <(curl -sL https://raw.githubusercontent.com/szp2005/ipok-cli/main/media.sh)
```

Results reflect the server's outbound IP (the proxy/VPS use-case). Streaming providers change endpoints often, so treat results as best-effort.

## Why

Most IP-purity tools give a single black-box score. IPOK aggregates multiple risk sources and shows **why** an IP is flagged, plus AI-service availability and use-case fit — the stuff that actually matters for proxies, cross-border, and AI accounts.

## Free API (no auth, CORS-enabled)

The CLI just calls IPOK's public API. You can too:

```bash
curl "https://ipok.io/api/ip?ip=1.1.1.1"            # full IP report (JSON)
curl "https://ipok.io/api/bgp?asn=AS13335&ip=1.1.1.1"  # BGP upstreams/downstreams (RIPEstat)
curl "https://ipok.io/api/reverse-ip?ip=1.1.1.1"    # domains hosted on the IP
```

Docs: <https://ipok.io/developers>

### Response shape (`/api/ip`, excerpt)

```jsonc
{
  "geo":   { "ip", "version", "country", "city", "asn", "asName", "isp", "lat", "lon" },
  "ipType": "residential | hosting | mobile",
  "risk": 0,
  "nativeType": "native | broadcast | unknown",
  "scenarios": [{ "key": "tiktok", "stars": 3, "verdict": "try" }],
  "services":  [{ "key": "chatgpt", "status": "available" }],
  "sources":   [{ "source": "ip-api", "risk": 10, "flags": {} }],
  "rdap":      { "registry", "country", "registered", "org" }
}
```

## License

MIT — see [LICENSE](./LICENSE). Not affiliated with any provider; data is best-effort and for diagnostics only.
