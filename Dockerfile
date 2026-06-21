# INFATON MCP35 — remote MCP gateway for 1C:Enterprise
#
# The repository ships a *stdio* MCP server (index.mjs) that proxies tool calls
# to a 1C:Enterprise HTTP service. To make it reachable over the network behind
# a Coolify-managed HTTPS subdomain, we wrap it with `supergateway`, which bridges
# the stdio transport to SSE (Server-Sent Events).
#
# Exposed endpoints (port 8000):
#   GET  /sse      — SSE stream (server -> client)
#   POST /message  — client -> server messages
#   GET  /healthz  — health check, returns "ok"
#
# 1C connection is configured via environment variables (set them in Coolify):
#   ONEC_URL           — base URL of the 1C HTTP service, e.g. https://server/base/hs/mcp/
#   ONEC_USER          — 1C username
#   ONEC_PASSWORD      — 1C password
#   ONEC_ALLOWED_TOOLS — optional comma-separated whitelist of tool names
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

# stdio (node index.mjs) -> SSE on :8000
CMD ["sh", "-c", "supergateway --stdio 'node /app/index.mjs' --outputTransport sse --port \"${PORT:-8000}\" --ssePath /sse --messagePath /message --healthEndpoint /healthz --cors --logLevel info"]
