import crypto from 'node:crypto';

// NFR-5: per-user daily quota, a burst limiter, and request de-duplication.
//
// State is in-memory, which is correct for a single instance. When you run more
// than one instance, move `usage` and `recent` to a shared store (Redis,
// Firestore, ...) behind the same interface.

const utcDay = (now) => new Date(now).toISOString().slice(0, 10);

function nextUtcMidnight(now) {
  const d = new Date(now);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1)).toISOString();
}

export class QuotaLedger {
  constructor({ dailyQuota, minRequestIntervalMs }) {
    this.dailyQuota = dailyQuota;
    this.minRequestIntervalMs = minRequestIntervalMs;
    this.usage = new Map(); // userId -> { day, used, lastChargedAt }
  }

  #entry(userId, now) {
    const day = utcDay(now);
    let entry = this.usage.get(userId);
    if (!entry || entry.day !== day) {
      entry = { day, used: 0, lastChargedAt: entry?.lastChargedAt ?? 0 };
      this.usage.set(userId, entry);
    }
    return entry;
  }

  status(userId, now = Date.now()) {
    const { used } = this.#entry(userId, now);
    return {
      limit: this.dailyQuota,
      used,
      remaining: Math.max(0, this.dailyQuota - used),
      resetsAt: nextUtcMidnight(now),
    };
  }

  /**
   * Reserves one request. Returns { ok: true } or
   * { ok: false, code: 'rate_limited' | 'quota_exceeded', retryAfterMs }.
   */
  tryCharge(userId, now = Date.now()) {
    const entry = this.#entry(userId, now);
    const sinceLast = now - entry.lastChargedAt;
    if (sinceLast < this.minRequestIntervalMs) {
      return { ok: false, code: 'rate_limited', retryAfterMs: this.minRequestIntervalMs - sinceLast };
    }
    if (entry.used >= this.dailyQuota) {
      return {
        ok: false,
        code: 'quota_exceeded',
        retryAfterMs: Date.parse(nextUtcMidnight(now)) - now,
      };
    }
    entry.used += 1;
    entry.lastChargedAt = now;
    return { ok: true };
  }

  /** Gives a request back when the upstream call failed through no fault of the user. */
  refund(userId, now = Date.now()) {
    const entry = this.#entry(userId, now);
    entry.used = Math.max(0, entry.used - 1);
  }
}

/**
 * Coalesces identical requests: concurrent duplicates share one upstream call,
 * and a completed result is replayed for `windowMs` without charging quota.
 */
export class RequestDeduper {
  constructor({ windowMs }) {
    this.windowMs = windowMs;
    this.entries = new Map(); // key -> { promise, expiresAt }
  }

  static key(userId, action, text, question = null) {
    return crypto
      .createHash('sha256')
      .update(`${userId}\u0000${action}\u0000${text}\u0000${question ?? ''}`)
      .digest('hex');
  }

  get(key, now = Date.now()) {
    const entry = this.entries.get(key);
    if (!entry) return null;
    if (entry.expiresAt !== null && entry.expiresAt <= now) {
      this.entries.delete(key);
      return null;
    }
    return entry.promise;
  }

  track(key, promise) {
    const entry = { promise, expiresAt: null };
    this.entries.set(key, entry);
    promise.then(
      () => {
        entry.expiresAt = Date.now() + this.windowMs;
      },
      () => {
        // Failures are never replayed; the next attempt goes upstream again.
        if (this.entries.get(key) === entry) this.entries.delete(key);
      },
    );
    this.#sweep();
    return promise;
  }

  #sweep(now = Date.now()) {
    if (this.entries.size < 1000) return;
    for (const [key, entry] of this.entries) {
      if (entry.expiresAt !== null && entry.expiresAt <= now) this.entries.delete(key);
    }
  }
}
