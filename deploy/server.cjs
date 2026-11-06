'use strict';
// Serve the original teacher build without changing index.js or package.json.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, '..', 'dist', 'index.html'));
const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || '0.0.0.0';
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');
const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, {Allow: 'GET, HEAD'}); res.end(); return;
  }
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (pathname === '/healthz') {
    res.writeHead(200, {'Content-Type': 'text/plain; charset=utf-8'});
    res.end(req.method === 'HEAD' ? undefined : 'ok\n');
  } else if (pathname === '/') {
    res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8', 'Content-Length': html.length});
    res.end(req.method === 'HEAD' ? undefined : html);
  } else {res.writeHead(404); res.end();}
});
server.listen(port, host, () => console.log(`Teacher build listening on ${host}:${port}`));
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close(() => process.exit(0)));
