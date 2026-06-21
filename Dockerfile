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
COPY index.mjs package.json ./

ENV PORT=8000
EXPOSE 8000

# stdio (node index.mjs) -> Streamable HTTP on :8000.
# --stateful keeps a separate per-session server instance (required: the legacy
# SSE gateway shared one instance and crashed with "Already connected" when a
# client opened a second connection).
CMD ["sh", "-c", "supergateway --stdio 'node /app/index.mjs' --outputTransport streamableHttp --stateful --streamableHttpPath \"${MCP_PATH:-/mcp}\" --port \"${PORT:-8000}\" --healthEndpoint /healthz --cors --logLevel info"]
