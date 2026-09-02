import { Strings } from 'c/strings';
import { ErrorParser } from './errorParser';

/**
 * Produces an error message string from a fetch response error.
 *
 * A fetch response error is received when a fetch request (e.g. UI API read,
 * write, etc.) fails.
 *
 * These errors look like this:
 * {
 *   "constituentField": null,
 *   "duplicateRecordError": null,
 *   "errorCode": "FIELD_CUSTOM_VALIDATION_EXCEPTION",
 *   "field": null,
 *   "fieldLabel": null,
 *   "message": "The best error message."
 * }
 */
const parseFetchResponseError = (fetchResponseError) => {
  const errorMessageParts = [];
  if (fetchResponseError.field) {
    errorMessageParts.push(`(${fetchResponseError.field})`);
  }

  if (fetchResponseError.message) {
    errorMessageParts.push(fetchResponseError.message);
  }

  return `${fetchResponseError.errorCode}: ${errorMessageParts.join(' - ')}`;
};

/**
 * Contains implementations of {@link ErrorParser}.
 */
export class ErrorParsers {
  static EMP_API_ERROR = new ErrorParser(
    (error) => typeof error?.channel === 'string',
    (error) => {
      let errorMessage = `${error.channel}: ${error.error}`;

      if (error.advice) {
        errorMessage += ` (reconnect: ${error.advice.reconnect}, interval: ${error.advice.interval})`;
      }

      return errorMessage;
    }
  );
  static FIELD_ERROR = new ErrorParser(
    (error) =>
      error?.body?.fieldErrors &&
      typeof error.body.fieldErrors === 'object' &&
      // eslint-disable-next-line compat/compat
      Reflect.ownKeys(error.body.fieldErrors).length > 0,
    (error) => {
      // `fieldErrors` is an object with the names of the fields as keys and an
      // array of error objects as values
      // eslint-disable-next-line compat/compat
      const fields = Reflect.ownKeys(error.body.fieldErrors);

      const errorMessages = [];
      for (const field of fields) {
        const fieldErrors = error.body.fieldErrors[field];
        if (Array.isArray(fieldErrors)) {
          for (const fieldError of fieldErrors) {
            errorMessages.push(
              `${fieldError.statusCode}: ${fieldError.message}`
            );
          }
        }
      }

      return errorMessages.join('\n');
    }
  );
  static HTTP_STATUS_TEXT = new ErrorParser(
    (error) => Boolean(error?.statusText) && error.statusText !== '',
    (error) => String(error.statusText)
  );
  static JS_ERROR = new ErrorParser(
    (error) => typeof error?.message === 'string' && error.message !== '',
    (error) => String(error.message)
  );
  static PAGE_ERROR = new ErrorParser(
    (error) =>
      Array.isArray(error?.body?.pageErrors) &&
      error.body.pageErrors.length > 0,
    (error) =>
      error.body.pageErrors
        .map((pageError) => {
          const statusCode = pageError.statusCode;
          const message = pageError.message;

          // Sometimes one of these is not populated
          const errorMessageParts = [statusCode, message];
          if (errorMessageParts.some(Strings.isEmpty)) {
            return errorMessageParts.filter(Strings.isEmpty);
          }
          return `${pageError.statusCode}: ${pageError.message}`;
        })
        .join('\n')
  );
  static STRING_ERROR = new ErrorParser(
    (error) => typeof error === 'string' && error !== '',
    (error) => error
  );
  static UI_API_READ_ERROR = new ErrorParser(
    (error) => Array.isArray(error?.body) && error.body.length > 0,
    (error) => error.body.map((e) => e.message)
  );
  static UI_API_WRITE_OR_APEX_OR_NETWORK_ERROR = new ErrorParser(
    (error) => error?.body && typeof error.body.message === 'string',
    (error) => {
      const errorMessages = [error.body.message];

      // Error details will be in the errors or fieldErrors keys within body
      if (typeof error.body.output === 'object') {
        if (Array.isArray(error.body.output.errors)) {
          for (const e of error.body.output.errors) {
            errorMessages.push(parseFetchResponseError(e));
          }
        }
        if (typeof error.body.output.fieldErrors === 'object') {
          for (const field of Reflect.ownKeys(error.body.output.fieldErrors)) {
            const fieldErrors = error.body.output.fieldErrors[field];
            for (const e of fieldErrors) {
              errorMessages.push(parseFetchResponseError(e));
            }
          }
        }
      }

      errorMessages.push(error.body.exceptionType);
      errorMessages.push(error.body.stackTrace);

      return errorMessages
        .map((str) => str?.trim())
        .filter((str) => str)
        .join('\n');
    }
  );
}