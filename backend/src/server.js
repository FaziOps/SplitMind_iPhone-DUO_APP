import crypto from 'node:crypto';
import http from 'node:http';
import { pathToFileURL } from 'node:url';

import { bearerToken, issueToken, verifyToken } from './auth.js';
import { loadConfig } from './config.js';
import { ACTIONS, QUESTION_ACTIONS, buildPrompt } from './prompts.js';
import { ProviderError } from './providers/errors.js';
import { createGeminiProvider } from './providers/gemini.js';
import { createMockProvider } from './providers/mock.js';
import { QuotaLedger, RequestDeduper } from './quota.js';

const MAX_BODY_BYTES = 64 * 1024;
const MAX_QUESTION_CHARS = 500;

class HttpError extends Error {
  constructor(status, code, message, extra = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }
}

function sendJson(res, status, body, headers = {}) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
    'cache-control': 'no-store',
    ...headers,
  });
  res.end(payload);
}

async function readJson(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw new HttpError(413, 'payload_too_large', 'Request body too large');
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw new HttpError(400, 'invalid_request', 'Body must be valid JSON');
  }
}

// Usage log for cost monitoring (PRD Section 5). Never logs passage text or
// output: content is not retained server-side (NFR-7).
function logUsage(fields) {
  console.log(JSON.stringify({ ts: new Date().toISOString(), event: 'synthesize', ...fields }));
}

const hashUser = (userId) => crypto.createHash('sha256').update(userId).digest('hex').slice(0, 12);

export function createProvider(config) {
  return config.provider === 'gemini'
    ? createGeminiProvider({ ...config.gemini, timeoutMs: config.upstreamTimeoutMs })
    : createMockProvider({ latencyMs: config.mockLatencyMs });
}

export function createApp(config, { provider = createProvider(config), now = () => Date.now() } = {}) {
  const ledger = new QuotaLedger(config);
  const deduper = new RequestDeduper({ windowMs: config.dedupeWindowMs });

  function authenticate(req) {
    const userId = verifyToken(bearerToken(req), config.tokenSecret, now());
    if (!userId) throw new HttpError(401, 'unauthorized', 'Missing or invalid token');
    return userId;
  }

  function validateSynthesis(body) {
    const { text, action, question = null, docId = null, page = null } = body ?? {};
    if (typeof text !== 'string' || !text.trim()) {
      throw new HttpError(400, 'invalid_request', '"text" must be a non-empty string');
    }
    if (!ACTIONS.includes(action)) {
      throw new HttpError(400, 'invalid_request', `"action" must be one of: ${ACTIONS.join(', ')}`);
    }
    const trimmed = text.trim();
    if (trimmed.length > config.maxTextChars) {
      throw new HttpError(413, 'text_too_long', `Select at most ${config.maxTextChars} characters`, {
        maxChars: config.maxTextChars,
      });
    }
    let trimmedQuestion = null;
    if (QUESTION_ACTIONS.includes(action)) {
      if (typeof question !== 'string' || !question.trim()) {
        throw new HttpError(400, 'invalid_request', `"question" is required for "${action}"`);
      }
      trimmedQuestion = question.trim();
      if (trimmedQuestion.length > MAX_QUESTION_CHARS) {
        throw new HttpError(413, 'question_too_long', `Ask at most ${MAX_QUESTION_CHARS} characters`, {
          maxChars: MAX_QUESTION_CHARS,
        });
      }
    }
    if (docId !== null && typeof docId !== 'string') {
      throw new HttpError(400, 'invalid_request', '"docId" must be a string');
    }
    if (page !== null && !Number.isInteger(page)) {
      throw new HttpError(400, 'invalid_request', '"page" must be an integer');
    }
    return { text: trimmed, action, question: trimmedQuestion, docId, page };
  }

  const routes = {
    'GET /health': async () => [200, { status: 'ok', provider: provider.name }],

    // Issues an anonymous, device-scoped identity. Replace with real sign-in
    // before launch; quotas key off whatever user id verifyToken() returns.
    'POST /v1/auth/anonymous': async () => {
      const userId = `anon_${crypto.randomUUID()}`;
      const token = issueToken({
        userId,
        secret: config.tokenSecret,
        ttlSeconds: config.tokenTtlSeconds,
        now: now(),
      });
      return [200, { token, userId, quota: ledger.status(userId, now()) }];
    },

    'GET /v1/quota': async (req) => {
      const userId = authenticate(req);
      return [200, { quota: ledger.status(userId, now()) }];
    },

    'POST /v1/synthesize': async (req) => {
      const userId = authenticate(req);
      const { text, action, question, docId, page } = validateSynthesis(await readJson(req));
      const started = now();
      const key = RequestDeduper.key(userId, action, text, question);

      const replay = deduper.get(key, started);
      if (replay) {
        const markdown = await replay;
        logUsage({ user: hashUser(userId), action, chars: text.length, status: 200, cached: true, latencyMs: now() - started });
        return [200, { id: crypto.randomUUID(), action, markdown, docId, page, model: provider.model, cached: true, quota: ledger.status(userId, now()) }];
      }

      const charge = ledger.tryCharge(userId, started);
      if (!charge.ok) {
        const message =
          charge.code === 'quota_exceeded'
            ? 'Daily AI limit reached. It resets at midnight UTC.'
            : 'Too many requests. Wait a moment and try again.';
        throw new HttpError(429, charge.code, message, {
          retryAfterMs: charge.retryAfterMs,
          quota: ledger.status(userId, started),
        });
      }

      const prompt = buildPrompt(action, text, question);
      try {
        const markdown = await deduper.track(key, provider.generate(prompt, action, { text, question }));
        logUsage({ user: hashUser(userId), action, chars: text.length, status: 200, cached: false, provider: provider.name, latencyMs: now() - started });
        return [200, { id: crypto.randomUUID(), action, markdown, docId, page, model: provider.model, cached: false, quota: ledger.status(userId, now()) }];
      } catch (err) {
        // Upstream failures are not the user's fault: give the request back.
        // Safety blocks still count, so the filter can't be probed for free.
        const code = err instanceof ProviderError ? err.code : 'upstream_error';
        if (code !== 'safety_blocked') ledger.refund(userId, now());
        const status = code === 'safety_blocked' ? 422 : code === 'upstream_timeout' ? 504 : 502;
        logUsage({ user: hashUser(userId), action, chars: text.length, status, error: code, provider: provider.name, latencyMs: now() - started });
        if (code === 'upstream_error') console.error('[provider]', err?.message ?? err);
        const message = {
          safety_blocked: 'The AI provider declined to process this passage.',
          upstream_timeout: 'The AI provider took too long to respond.',
          upstream_error: 'The AI provider is unavailable right now.',
        }[code];
        throw new HttpError(status, code, message, { quota: ledger.status(userId, now()) });
      }
    },
  };

  return async function handle(req, res) {
    const pathname = new URL(req.url, 'http://localhost').pathname;
    const route = routes[`${req.method} ${pathname}`];
    try {
      if (!route) throw new HttpError(404, 'not_found', 'Route not found');
      const [status, body] = await route(req);
      sendJson(res, status, body);
    } catch (err) {
      if (err instanceof HttpError) {
        const headers = err.extra.retryAfterMs
          ? { 'retry-after': String(Math.ceil(err.extra.retryAfterMs / 1000)) }
          : {};
        sendJson(res, err.status, { error: err.code, message: err.message, ...err.extra }, headers);
      } else {
        console.error('[server]', err);
        sendJson(res, 500, { error: 'internal', message: 'Internal server error' });
      }
    }
  };
}

export function startServer(config = loadConfig()) {
  const server = http.createServer(createApp(config));
  server.listen(config.port, () => {
    console.log(`[splitmind] listening on http://localhost:${config.port} (provider: ${config.provider})`);
  });
  return server;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  startServer();
}
