# INFATON MCP35 — remote MCP gateway for 1C:Enterprise
#
# The repository ships a *stdio* MCP server (index.mjs) that proxies tool calls
# to a 1C:Enterprise HTTP service. To make it reachable over the network behind
# a Coolify-managed HTTPS subdomain, we wrap it with `supergateway`, which bridges
# the stdio transport to Streamable HTTP (a single-URL, session-aware transport
# that modern MCP clients such as claude.ai use).
#
# Exposed endpoints (port 8000):
#   POST/GET <MCP_PATH>  — Streamable HTTP MCP endpoint, default /mcp
#   GET      /healthz    — health check, returns "ok" (always public)
#
# 1C connection is configured via environment variables (set them in Coolify):
#   ONEC_URL           — base URL of the 1C HTTP service, e.g. https://server/base/hs/mcp/
#   ONEC_USER          — 1C username
#   ONEC_PASSWORD      — 1C password
#   ONEC_ALLOWED_TOOLS — optional comma-separated whitelist of tool names
#   MCP_PATH           — optional override of the MCP endpoint path.
#                        Embedding a long random token (e.g. /s/<token>/mcp)
#                        turns the URL itself into the access credential.
#
# Without ONEC_URL the server still answers `initialize` and `tools/list`
# (demo/inspection mode) but returns an error for `tools/call`.

FROM node:20-alpine

# supergateway bridges a stdio MCP server to SSE / Streamable HTTP.
# Pinned for reproducible builds.
RUN npm install -g supergateway@3.4.3

WORKDIR /app
COPY index.mjs package.json guard.cjs shim.mjs ./

ENV PORT=8000
EXPOSE 8000

# Two processes in the container:
#   1. supergateway in STATELESS Streamable HTTP mode on :8001 (no sessions, so
#      restarts can't strand a client on a dead session id — the failure mode
#      that stateful mode hit: it returns 400, not the 404 clients re-init on).
#   2. shim.mjs on :8000 (the exposed port): proxies to :8001, but answers GET
#      on the MCP path with 200 SSE so stateless's 405 can't trigger a client's
#      OAuth fallback. guard.cjs keeps a dropped connection from crashing the
#      gateway process.
CMD ["sh", "-c", "node --require /app/guard.cjs \"$(command -v supergateway)\" --stdio 'node /app/index.mjs' --outputTransport streamableHttp --streamableHttpPath \"${MCP_PATH:-/mcp}\" --port 8001 --healthEndpoint /healthz --cors --logLevel info & UPSTREAM_PORT=8001 exec node /app/shim.mjs"]
