import assert from 'node:assert/strict';
import http from 'node:http';
import { after, before, describe, test } from 'node:test';

import { loadConfig } from '../src/config.js';
import { createApp } from '../src/server.js';
import { createMockProvider } from '../src/providers/mock.js';

function startTestServer(overrides = {}, deps = {}) {
  const config = {
    ...loadConfig({ TOKEN_SECRET: 'test-secret', MOCK_LATENCY_MS: '0' }),
    minRequestIntervalMs: 0,
    ...overrides,
  };
  const server = http.createServer(createApp(config, { provider: createMockProvider(), ...deps }));
  return new Promise((resolve) => {
    server.listen(0, () => {
      const base = `http://127.0.0.1:${server.address().port}`;
      resolve({ server, base });
    });
  });
}

async function call(base, method, path, { token, body } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: await res.json() };
}

async function anonymousToken(base) {
  const { body } = await call(base, 'POST', '/v1/auth/anonymous');
  return body.token;
}

describe('SplitMind proxy', () => {
  let ctx;
  before(async () => {
    ctx = await startTestServer({ dailyQuota: 3 });
  });
  after(() => ctx.server.close());

  test('health check reports provider', async () => {
    const { status, body } = await call(ctx.base, 'GET', '/health');
    assert.equal(status, 200);
    assert.equal(body.provider, 'mock');
  });

  test('rejects synthesize without a token', async () => {
    const { status, body } = await call(ctx.base, 'POST', '/v1/synthesize', {
      body: { text: 'Hello.', action: 'summarize' },
    });
    assert.equal(status, 401);
    assert.equal(body.error, 'unauthorized');
  });

  test('rejects a tampered token', async () => {
    const token = await anonymousToken(ctx.base);
    const tampered = token.slice(0, -2) + (token.endsWith('AA') ? 'BB' : 'AA');
    const { status } = await call(ctx.base, 'GET', '/v1/quota', { token: tampered });
    assert.equal(status, 401);
  });

  test('validates action and text', async () => {
    const token = await anonymousToken(ctx.base);
    const badAction = await call(ctx.base, 'POST', '/v1/synthesize', {
      token,
      body: { text: 'Hi.', action: 'rewrite' },
    });
    assert.equal(badAction.status, 400);
    const empty = await call(ctx.base, 'POST', '/v1/synthesize', {
      token,
      body: { text: '   ', action: 'explain' },
    });
    assert.equal(empty.status, 400);
  });

  test('returns markdown and charges quota once for duplicate requests', async () => {
    const token = await anonymousToken(ctx.base);
    const body = { text: 'Spaced repetition improves recall. It works.', action: 'summarize', docId: 'd1', page: 2 };
    const first = await call(ctx.base, 'POST', '/v1/synthesize', { token, body });
    assert.equal(first.status, 200);
    assert.match(first.body.markdown, /### Summary/);
    assert.equal(first.body.page, 2);
    assert.equal(first.body.quota.used, 1);

    const second = await call(ctx.base, 'POST', '/v1/synthesize', { token, body });
    assert.equal(second.status, 200);
    assert.equal(second.body.cached, true);
    assert.equal(second.body.quota.used, 1);
  });

  test('answers every new action in its Markdown shape', async () => {
    const text =
      'The cornea is the clear front window of the eye. The lens changes shape to focus. ' +
      'The retina converts light into nerve signals.';
    const expected = {
      simplify: /### In simple words[\s\S]*### Example/,
      terms: /### Key terms\n- \*\*/,
      quiz: /### Quiz[\s\S]*- A\)[\s\S]*### Answers\n1\. [A-D] —/,
    };
    for (const [action, shape] of Object.entries(expected)) {
      const { server, base } = await startTestServer();
      try {
        const token = await anonymousToken(base);
        const r = await call(base, 'POST', '/v1/synthesize', { token, body: { text, action } });
        assert.equal(r.status, 200, action);
        assert.equal(r.body.action, action);
        assert.match(r.body.markdown, shape, action);
      } finally {
        server.close();
      }
    }
  });

  test('ask requires a question and answers from the passage', async () => {
    const { server, base } = await startTestServer();
    try {
      const token = await anonymousToken(base);
      const text = 'The lens changes shape to focus. The retina converts light into nerve signals.';
      const missing = await call(base, 'POST', '/v1/synthesize', { token, body: { text, action: 'ask' } });
      assert.equal(missing.status, 400);
      const blank = await call(base, 'POST', '/v1/synthesize', { token, body: { text, action: 'ask', question: '  ' } });
      assert.equal(blank.status, 400);
      const tooLong = await call(base, 'POST', '/v1/synthesize', {
        token,
        body: { text, action: 'ask', question: 'x'.repeat(501) },
      });
      assert.equal(tooLong.status, 413);
      assert.equal(tooLong.body.error, 'question_too_long');

      const answer = await call(base, 'POST', '/v1/synthesize', {
        token,
        body: { text, action: 'ask', question: 'What does the retina do?' },
      });
      assert.equal(answer.status, 200);
      assert.match(answer.body.markdown, /### Answer\n.*retina converts light/);
      assert.match(answer.body.markdown, /### From the passage/);
    } finally {
      server.close();
    }
  });

  test('does not replay an answer to a different question', async () => {
    const { server, base } = await startTestServer();
    try {
      const token = await anonymousToken(base);
      const text = 'The lens changes shape to focus. The retina converts light into nerve signals.';
      const ask = (question) => call(base, 'POST', '/v1/synthesize', { token, body: { text, action: 'ask', question } });
      const first = await ask('What does the lens do?');
      const second = await ask('What does the retina do?');
      assert.equal(second.body.cached, false);
      assert.notEqual(first.body.markdown, second.body.markdown);
      assert.equal((await ask('What does the retina do?')).body.cached, true);
    } finally {
      server.close();
    }
  });

  test('enforces the daily quota', async () => {
    const token = await anonymousToken(ctx.base);
    for (let i = 0; i < 3; i++) {
      const r = await call(ctx.base, 'POST', '/v1/synthesize', {
        token,
        body: { text: `Passage number ${i}.`, action: 'explain' },
      });
      assert.equal(r.status, 200);
    }
    const blocked = await call(ctx.base, 'POST', '/v1/synthesize', {
      token,
      body: { text: 'One more.', action: 'explain' },
    });
    assert.equal(blocked.status, 429);
    assert.equal(blocked.body.error, 'quota_exceeded');
    assert.equal(blocked.body.quota.remaining, 0);
  });

  test('maps safety blocks to 422 and refunds upstream errors', async () => {
    const token = await anonymousToken(ctx.base);
    const safety = await call(ctx.base, 'POST', '/v1/synthesize', {
      token,
      body: { text: 'Bad [[safety]] text.', action: 'explain' },
    });
    assert.equal(safety.status, 422);
    assert.equal(safety.body.error, 'safety_blocked');
    assert.equal(safety.body.quota.used, 1);

    const upstream = await call(ctx.base, 'POST', '/v1/synthesize', {
      token,
      body: { text: 'Flaky [[upstream]] text.', action: 'explain' },
    });
    assert.equal(upstream.status, 502);
    assert.equal(upstream.body.quota.used, 1);
  });
});

describe('burst limiter', () => {
  let ctx;
  before(async () => {
    ctx = await startTestServer({ minRequestIntervalMs: 60_000 });
  });
  after(() => ctx.server.close());

  test('rejects rapid-fire distinct requests', async () => {
    const token = await anonymousToken(ctx.base);
    const ok = await call(ctx.base, 'POST', '/v1/synthesize', {
      token,
      body: { text: 'First.', action: 'summarize' },
    });
    assert.equal(ok.status, 200);
    const limited = await call(ctx.base, 'POST', '/v1/synthesize', {
      token,
      body: { text: 'Second.', action: 'summarize' },
    });
    assert.equal(limited.status, 429);
    assert.equal(limited.body.error, 'rate_limited');
  });
});
