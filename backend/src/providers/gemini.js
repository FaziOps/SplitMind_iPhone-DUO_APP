import { ProviderError } from './errors.js';

// Gemini REST API (generateContent). The key is sent in a header, never in the
// URL, so it cannot leak into proxy or access logs.
export function createGeminiProvider({ apiKey, model, timeoutMs, fetchImpl = fetch }) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;

  return {
    name: 'gemini',
    model,
    async generate({ system, user }) {
      let response;
      try {
        response = await fetchImpl(url, {
          method: 'POST',
          headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: system }] },
            contents: [{ role: 'user', parts: [{ text: user }] }],
            generationConfig: { temperature: 0.4, maxOutputTokens: 1024 },
          }),
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch (err) {
        if (err?.name === 'TimeoutError' || err?.name === 'AbortError') {
          throw new ProviderError('upstream_timeout', 'Model request timed out');
        }
        throw new ProviderError('upstream_error', `Model request failed: ${err?.message ?? err}`);
      }

      const body = await response.json().catch(() => null);
      if (!response.ok) {
        const detail = body?.error?.message ?? `HTTP ${response.status}`;
        throw new ProviderError('upstream_error', `Model returned an error: ${detail}`);
      }

      if (body?.promptFeedback?.blockReason) {
        throw new ProviderError('safety_blocked', `Prompt blocked: ${body.promptFeedback.blockReason}`);
      }
      const candidate = body?.candidates?.[0];
      if (candidate?.finishReason === 'SAFETY' || candidate?.finishReason === 'PROHIBITED_CONTENT') {
        throw new ProviderError('safety_blocked', `Response blocked: ${candidate.finishReason}`);
      }
      const text = (candidate?.content?.parts ?? [])
        .map((part) => part.text ?? '')
        .join('')
        .trim();
      if (!text) throw new ProviderError('upstream_error', 'Model returned an empty response');
      return text;
    },
  };
}
