import crypto from 'node:crypto';

function intFromEnv(env, name, fallback) {
  const raw = env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number.parseInt(raw, 10);
  if (!Number.isFinite(value) || value < 0) {
    throw new Error(`${name} must be a non-negative integer, got "${raw}"`);
  }
  return value;
}

export function loadConfig(env = process.env) {
  const provider = (env.AI_PROVIDER || 'mock').toLowerCase();
  if (!['mock', 'gemini'].includes(provider)) {
    throw new Error(`AI_PROVIDER must be "mock" or "gemini", got "${provider}"`);
  }

  const isProduction = env.NODE_ENV === 'production';
  let tokenSecret = env.TOKEN_SECRET;
  if (!tokenSecret) {
    if (isProduction) throw new Error('TOKEN_SECRET is required in production');
    // Dev convenience: tokens stop validating when the process restarts, and the
    // app transparently re-authenticates on the resulting 401.
    tokenSecret = crypto.randomBytes(32).toString('hex');
    console.warn('[config] TOKEN_SECRET not set; using an ephemeral dev secret');
  }

  if (provider === 'gemini') {
    if (!env.GEMINI_API_KEY) throw new Error('GEMINI_API_KEY is required when AI_PROVIDER=gemini');
    if (!env.GEMINI_MODEL) throw new Error('GEMINI_MODEL is required when AI_PROVIDER=gemini');
  }

  return {
    port: intFromEnv(env, 'PORT', 8787),
    provider,
    gemini: {
      apiKey: env.GEMINI_API_KEY || '',
      model: env.GEMINI_MODEL || '',
    },
    tokenSecret,
    tokenTtlSeconds: intFromEnv(env, 'TOKEN_TTL_SECONDS', 60 * 60 * 24 * 30),
    dailyQuota: intFromEnv(env, 'DAILY_QUOTA', 200),
    minRequestIntervalMs: intFromEnv(env, 'MIN_REQUEST_INTERVAL_MS', 1000),
    dedupeWindowMs: intFromEnv(env, 'DEDUPE_WINDOW_MS', 15000),
    maxTextChars: intFromEnv(env, 'MAX_TEXT_CHARS', 8000),
    upstreamTimeoutMs: intFromEnv(env, 'UPSTREAM_TIMEOUT_MS', 25000),
    mockLatencyMs: intFromEnv(env, 'MOCK_LATENCY_MS', 500),
  };
}
