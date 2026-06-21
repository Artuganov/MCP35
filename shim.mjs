#!/usr/bin/env node
// Thin HTTP front for supergateway running in STATELESS Streamable HTTP mode.
//
// Why this exists:
//  - STATEFUL Streamable HTTP keeps per-session state. Any server restart
//    (redeploy, crash, host maintenance) wipes sessions, and supergateway then
//    answers a request bearing an old session id with HTTP 400 (not 404). The
//    MCP spec only tells clients to re-initialize on 404, so clients such as
//    claude.ai cannot auto-recover and the connector stays broken until the
//    user removes and re-adds it. STATELESS mode has no sessions, so it is
//    immune to this.
//  - STATELESS supergateway, however, answers GET on the MCP endpoint with 405.
//    Some clients open a GET event-stream and treat a 405 as a failure. This
//    shim answers GET on the MCP path with a 200 text/event-stream keep-alive
//    (responses still flow over each POST's own response), and transparently
//    proxies everything else to the stateless supergateway upstream.
import http from 'node:http';

const PORT = parseInt(process.env.PORT || '8000', 10);
const UPSTREAM_PORT = parseInt(process.env.UPSTREAM_PORT || '8001', 10);
const MCP_PATH = process.env.MCP_PATH || '/mcp';

const server = http.createServer((req, res) => {
  const path = (req.url || '/').split('?')[0];

  // GET on the MCP endpoint -> open an empty SSE keep-alive stream (200),
  // instead of letting stateless supergateway answer 405.
  if (req.method === 'GET' && path === MCP_PATH) {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write(': connected\n\n');
    const ka = setInterval(() => { try { res.write(': keep-alive\n\n'); } catch {} }, 15000);
    req.on('close', () => clearInterval(ka));
    return;
  }

  // Everything else -> proxy to the stateless supergateway upstream.
  const proxyReq = http.request(
    { host: '127.0.0.1', port: UPSTREAM_PORT, method: req.method, path: req.url, headers: req.headers },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode || 502, proxyRes.headers);
      proxyRes.pipe(res);
    },
  );
  proxyReq.on('error', () => {
    if (!res.headersSent) res.writeHead(502, { 'Content-Type': 'text/plain' });
    res.end('upstream unavailable');
  });
  req.pipe(proxyReq);
});

server.listen(PORT, () => {
  process.stderr.write(`[shim] listening :${PORT} -> upstream :${UPSTREAM_PORT}, GET ${MCP_PATH} = 200 SSE\n`);
});
