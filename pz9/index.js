'use strict';
const http = require('node:http');
const { Pool } = require('pg');

function createServer(pool) {
  return http.createServer(async (req, res) => {
    const reply = (status, body) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(body));
    };
    try {
      if (req.method === 'GET' && req.url === '/') {
        return reply(200, { message: 'Hello world!', application: 'devops-node-ci', version: '1.1.0' });
      }
      if (req.method === 'GET' && req.url === '/healthz') {
        await pool.query('SELECT 1');
        return reply(200, { status: 'ok', database: 'connected' });
      }
      if (req.method === 'GET' && req.url === '/visits') {
        const result = await pool.query('SELECT COUNT(*)::int AS count FROM visits');
        return reply(200, { count: result.rows[0].count });
      }
      if (req.method === 'POST' && req.url === '/visits') {
        req.resume();
        const result = await pool.query('INSERT INTO visits DEFAULT VALUES RETURNING id, created_at');
        return reply(201, result.rows[0]);
      }
      req.resume();
      return reply(404, { error: 'not_found' });
    } catch (error) {
      // Do not expose database credentials or connection strings in responses/logs.
      console.error('Database operation failed:', error.code || 'unavailable');
      return reply(503, { error: 'database_unavailable' });
    }
  });
}

async function initializeDatabase(pool) {
  await pool.query('SELECT 1');
  await pool.query('CREATE TABLE IF NOT EXISTS visits (id BIGSERIAL PRIMARY KEY, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP)');
  console.log('PostgreSQL connection established');
}

async function main() {
  if (!process.env.PGPASSWORD) throw new Error('PGPASSWORD is required');
  const port = Number(process.env.PORT || 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');
  const pool = new Pool({
    host: process.env.PGHOST || '127.0.0.1', port: Number(process.env.PGPORT || 5432),
    user: process.env.PGUSER || 'nodeapp', password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE || 'nodeapp', max: 5,
    connectionTimeoutMillis: 3000, query_timeout: 3000,
  });
  pool.on('error', (error) => console.error('Idle database connection failed:', error.code || 'unavailable'));
  try { await initializeDatabase(pool); }
  catch (error) { await pool.end(); throw error; }
  const server = createServer(pool);
  server.requestTimeout = 10000;
  server.headersTimeout = 10000;
  server.listen(port, process.env.HOST || '127.0.0.1', () => console.log(`HTTP server listening on port ${port}`));
  const stop = () => {
    const timer = setTimeout(() => process.exit(1), 10000); timer.unref();
    server.close(async () => { await pool.end(); clearTimeout(timer); process.exit(0); });
  };
  process.once('SIGTERM', stop); process.once('SIGINT', stop);
}
if (require.main === module) main().catch((error) => { console.error('Startup failed:', error.code || error.message); process.exitCode = 1; });
module.exports = { createServer, initializeDatabase };
