export class ProviderError extends Error {
  /** @param {'safety_blocked'|'upstream_timeout'|'upstream_error'} code */
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
