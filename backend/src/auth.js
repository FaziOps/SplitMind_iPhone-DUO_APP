import crypto from 'node:crypto';

// Minimal HMAC-signed bearer tokens: base64url(payload).base64url(signature).
// In production, swap this for your identity provider (Sign in with Apple,
// Firebase Auth, ...) and keep verifyToken() as the single integration point.

const b64url = (buf) => Buffer.from(buf).toString('base64url');

function sign(data, secret) {
  return crypto.createHmac('sha256', secret).update(data).digest();
}

export function issueToken({ userId, secret, ttlSeconds, now = Date.now() }) {
  const iat = Math.floor(now / 1000);
  const payload = b64url(JSON.stringify({ sub: userId, iat, exp: iat + ttlSeconds }));
  return `${payload}.${b64url(sign(payload, secret))}`;
}

/** Returns the user id for a valid token, or null. */
export function verifyToken(token, secret, now = Date.now()) {
  if (typeof token !== 'string') return null;
  const [payload, signature, extra] = token.split('.');
  if (!payload || !signature || extra !== undefined) return null;

  const expected = sign(payload, secret);
  const actual = Buffer.from(signature, 'base64url');
  if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) {
    return null;
  }

  try {
    const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    if (typeof claims.sub !== 'string' || typeof claims.exp !== 'number') return null;
    if (claims.exp * 1000 <= now) return null;
    return claims.sub;
  } catch {
    return null;
  }
}

export function bearerToken(req) {
  const header = req.headers.authorization || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match ? match[1].trim() : null;
}
