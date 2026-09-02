/**
 * Common error handling logic.
 */
import LightningAlert from 'lightning/alert';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { ErrorMessages } from './errorMessages';
import { ErrorParsers } from './errorParsers';

/**
 * Contains the result of parsing an error.
 *
 * A single error can have one or many error messages. We include all of these
 * in the `messages` field to simplify how the caller works with this object.
 * They will ask to parse one error and get back one parse result with one or
 * many error messages.
 */
class ErrorParseResult {
  messages = [];

  /**
   * Returns {@code true} when the given message is a substring of at least one
   * of the messages of this {@code ErrorParseResult}.
   */
  hasErrorMessage(message) {
    return this.messages.some((m) => m.includes(message));
  }
}

/**
 * Contains common error handling logic.
 */
class ErrorHandler {
  /**
   * When {@code true}, the {@link Error} will be logged to the console when it
   * is being {@link ErrorHandler.parse}d.
   *
   * This is static so that it is a global setting. All components share the
   * same instance of {@link ErrorHandler} so that we have common behavior.
   */
  static isLoggingErrorsToTheConsole = false;

  /**
   * Title that will be used on all UI-based notifications about errors.
   */
  static notificationTitle = 'Error';

  static parsers = [
    ErrorParsers.STRING_ERROR,
    ErrorParsers.FIELD_ERROR,
    ErrorParsers.PAGE_ERROR,
    ErrorParsers.UI_API_READ_ERROR,
    ErrorParsers.UI_API_WRITE_OR_APEX_OR_NETWORK_ERROR,
    ErrorParsers.EMP_API_ERROR,
    ErrorParsers.JS_ERROR,
    ErrorParsers.HTTP_STATUS_TEXT
  ];

  /**
   * Parses the {@link Error}, returning the {@link ErrorParseResult}.
   */
  static parse(error) {
    ErrorHandler.maybeLogToConsole(error);

    if (error == null) {
      error = [];
    } else if (!Array.isArray(error)) {
      error = [error];
    }

    const result = new ErrorParseResult();
    error.forEach((e) => {
      // An error can only have 1 parser
      const parser = ErrorHandler.parsers.find((p) => p.isParserFor(e));
      if (parser) {
        result.messages.push(parser.buildErrorMessage(e));
      }
    });

    return result;
  }

  /**
   * Parses the error of an unknown shape and throws it.
   */
  static parseAndThrow(error) {
    throw new Error(ErrorHandler.parse(error).messages.join('\n'));
  }

  /**
   * Displays an alert with the {@link Error}.
   *
   * The `error` should be the raw {@link Error} object. It does not need to be
   * {@link ErrorHandler.parse}d first. This method will take care of that.
   */
  static alert(error, title = ErrorHandler.notificationTitle) {
    LightningAlert.open({
      label: title,
      message: ErrorHandler.parse(error).messages.join('\n'),
      theme: 'error'
    }).catch((e) => {
      // eslint-disable-next-line no-console
      console.error('Failed to open the error alert', e);
    });
  }

  /**
   * Toasts the {@link Error} on the component.
   *
   * The `error` should be the raw {@link Error} object. It does not need to be
   * {@link ErrorHandler.parse}d first. This method will take care of that.
   */
  static toast(component, error, title = ErrorHandler.notificationTitle) {
    component.dispatchEvent(
      new ShowToastEvent({
        title,
        message: ErrorHandler.parse(error).messages.join(', '),
        variant: 'error',
        mode: 'sticky'
      })
    );
  }

  /**
   * Logs the error to the console when
   * {@link ErrorHandler.isLoggingErrorsToTheConsole} is {@code true}.
   */
  static maybeLogToConsole(error) {
    if (ErrorHandler.isLoggingErrorsToTheConsole) {
      // eslint-disable-next-line no-console
      console.error(JSON.stringify(error ?? {}, null, 2));
    }
  }
}

export { ErrorHandler, ErrorMessages };