/// A tiny typed result so async ops never throw raw exceptions to the UI.
library;

/// Either a success value [T] or a human-readable [message].
sealed class Result<T> {
  const Result();
}

/// Successful outcome carrying [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

/// Failed outcome carrying a user-safe [message].
final class Err<T> extends Result<T> {
  const Err(this.message);
  final String message;
}
