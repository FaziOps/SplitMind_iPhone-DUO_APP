import { ProviderError } from './errors.js';

// Deterministic, offline stand-in for local development and tests. It follows
// the same Markdown contract as the real prompts (see prompts.js).
//
// Include "[[safety]]" or "[[upstream]]" in the passage to exercise the app's
// error states (PRD FR-11).

const sentencesOf = (text) =>
  text
    .replace(/\s+/g, ' ')
    .split(/(?<=[.!?])\s+/)
    .map((s) => s.trim())
    .filter(Boolean);

const clip = (s, n = 160) => (s.length > n ? `${s.slice(0, n - 1).trimEnd()}…` : s);

const wordsOf = (s) => s.toLowerCase().match(/[a-z][a-z'-]{3,}/g) ?? [];

// Longer words first, so the mock "terms" favour specialist vocabulary.
const keywordsOf = (text, limit) =>
  [...new Set(wordsOf(text))].sort((a, b) => b.length - a.length).slice(0, limit);

// Sentences sharing the most words with the question, in passage order.
function relevantSentences(sentences, question, limit) {
  const asked = new Set(wordsOf(question));
  const scored = sentences.map((s, i) => ({ s, i, score: wordsOf(s).filter((w) => asked.has(w)).length }));
  const hits = scored.filter((x) => x.score > 0).sort((a, b) => b.score - a.score || a.i - b.i);
  return hits.slice(0, limit).sort((a, b) => a.i - b.i).map((x) => x.s);
}

export function createMockProvider({ latencyMs = 0 } = {}) {
  return {
    name: 'mock',
    model: 'mock-1',
    async generate({ user }, action, { text, question = null } = {}) {
      if (latencyMs) await new Promise((r) => setTimeout(r, latencyMs));
      const passage = text ?? user.replace(/^Passage:\n"""\n|\n"""$/g, '');
      if (passage.includes('[[safety]]')) {
        throw new ProviderError('safety_blocked', 'Mock safety filter triggered');
      }
      if (passage.includes('[[upstream]]')) {
        throw new ProviderError('upstream_error', 'Mock upstream failure');
      }

      const sentences = sentencesOf(passage);
      const lead = sentences[0] ?? passage;
      const footer = '_Mock response — set AI_PROVIDER=gemini on the backend for real output._';
      switch (action) {
        case 'explain':
          return [
            '### Explanation',
            `In plain terms: ${clip(lead, 220)}`,
            '',
            '### Key ideas',
            ...sentences.slice(0, 4).map((s) => `- ${clip(s)}`),
            '',
            footer,
          ].join('\n');
        case 'flashcard':
          return sentences
            .slice(0, 3)
            .map((s, i) => `**Q:** What is point ${i + 1} of this passage?\n**A:** ${clip(s)}`)
            .join('\n\n---\n\n');
        case 'simplify':
          return [
            '### In simple words',
            `Here is the main idea: ${clip(lead, 200)}`,
            '',
            '### Example',
            `Think of it like this: ${clip(sentences[1] ?? lead, 160)}`,
            '',
            footer,
          ].join('\n');
        case 'terms':
          return [
            '### Key terms',
            ...keywordsOf(passage, 5).map((w) => {
              const where = sentences.find((s) => s.toLowerCase().includes(w)) ?? lead;
              return `- **${w}** — ${clip(where, 120)}`;
            }),
          ].join('\n');
        case 'quiz': {
          const picked = sentences.slice(0, 3);
          const letters = ['A', 'B', 'C', 'D'];
          const questions = picked.map((s, i) => {
            const correct = i % letters.length;
            const options = letters.map((l, j) => `- ${l}) ${j === correct ? clip(s, 90) : `Distractor ${j + 1}`}`);
            return [`**${i + 1}. Which statement matches the passage?**`, ...options].join('\n');
          });
          return [
            '### Quiz',
            questions.join('\n\n'),
            '',
            '### Answers',
            ...picked.map((_, i) => `${i + 1}. ${letters[i % letters.length]} — it is stated in the passage.`),
          ].join('\n');
        }
        case 'ask': {
          const support = relevantSentences(sentences, question ?? '', 3);
          return [
            '### Answer',
            support.length
              ? `Based on the passage: ${clip(support[0], 220)}`
              : `The passage doesn't answer that directly. It covers: ${clip(lead, 160)}`,
            '',
            '### From the passage',
            ...(support.length ? support : [lead]).map((s) => `- ${clip(s)}`),
          ].join('\n');
        }
        case 'summarize':
        default:
          return [
            '### Summary',
            ...sentences.slice(0, 5).map((s) => `- ${clip(s)}`),
            '',
            '### Takeaway',
            clip(lead, 200),
          ].join('\n');
      }
    },
  };
}
