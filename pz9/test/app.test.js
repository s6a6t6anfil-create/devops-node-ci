'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer, initializeDatabase } = require('../index');
async function withServer(pool, action) {
  const server = createServer(pool);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try { await action(`http://127.0.0.1:${server.address().port}`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
test('greeting and unknown route work without database queries', async () => {
  await withServer({ query: () => { throw new Error('unexpected query'); } }, async base => {
    const result = await fetch(base); assert.equal(result.status, 200);
    assert.equal((await result.json()).message, 'Hello world!');
    assert.equal((await fetch(`${base}/unknown`)).status, 404);
  });
});
test('health checks database and database errors yield 503 without leaking credentials', async () => {
  await withServer({ query: async () => ({ rows: [] }) }, async base => assert.equal((await fetch(`${base}/healthz`)).status, 200));
  await withServer({ query: async () => { const e = new Error('secret-not-for-response'); e.code = 'ECONNREFUSED'; throw e; } }, async base => {
    const response = await fetch(`${base}/healthz`); assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: 'database_unavailable' });
  });
});
test('visit writes and reads use SQL; mock is not a real PostgreSQL persistence test', async () => {
  let count = 0;
  const pool = { query: async sql => {
    if (sql.startsWith('INSERT')) return { rows: [{ id: String(++count), created_at: '2026-11-05T00:00:00Z' }] };
    return { rows: [{ count }] };
  } };
  await withServer(pool, async base => {
    assert.equal((await fetch(`${base}/visits`, { method: 'POST' })).status, 201);
    assert.deepEqual(await (await fetch(`${base}/visits`)).json(), { count: 1 });
  });
});
test('database initialization checks connectivity before creating table', async () => {
  const queries = []; await initializeDatabase({ query: async sql => { queries.push(sql); return { rows: [] }; } });
  assert.equal(queries[0], 'SELECT 1'); assert.match(queries[1], /^CREATE TABLE IF NOT EXISTS visits/);
});
