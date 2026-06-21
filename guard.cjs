// Crash guard for supergateway (preloaded via `node --require`).
//
// supergateway's stateful Streamable HTTP / SSE gateways throw *uncaught*
// exceptions when a client connection drops mid-request, e.g.:
//   "No connection established for request ID: N"   (client disconnected before
//                                                    the stdio child replied)
//   "Already connected to a transport"              (second concurrent stream)
// An uncaught exception terminates the whole Node process, which on a stateful
// server wipes every active session — so one slow query that makes a client
// time out takes the entire connector down for all users.
//
// These throws are isolated to a single request's delivery; the server is
// otherwise fine. Swallow them (with a log) so the process stays alive.
process.on('uncaughtException', (err) => {
  process.stderr.write('[guard] uncaughtException swallowed: ' + ((err && err.stack) || err) + '\n');
});
process.on('unhandledRejection', (reason) => {
  process.stderr.write('[guard] unhandledRejection swallowed: ' + ((reason && reason.stack) || reason) + '\n');
});
