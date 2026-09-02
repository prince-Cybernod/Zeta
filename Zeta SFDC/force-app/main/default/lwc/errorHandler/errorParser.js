/**
 * Parses an {@link Error}.
 */
export class ErrorParser {
  /**
   * Returns {@code true} when this is the {@link ErrorParser} for the given
   * {@link Error}.
   */
  // eslint-disable-next-line no-unused-vars
  isParserFor = (error) => false;

  /**
   * Builds and returns an error message for the given {@link Error}.
   */
  // eslint-disable-next-line no-unused-vars
  buildErrorMessage = (error) => '';

  constructor(isParserFor, buildErrorMessage) {
    this.isParserFor = isParserFor;
    this.buildErrorMessage = buildErrorMessage;
  }
}