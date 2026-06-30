/// Detects "cancel/delete this reminder" intent in free text and extracts the
/// target phrase to match against existing reminders.
library;

/// A request to cancel a reminder matching [target] (may be empty → ambiguous).
final class CancelRequest {
  const CancelRequest(this.target);
  final String target;
}

const _cancelVerbs = r'cancel|delete|remove|forget|drop|clear|stop|undo';

/// Returns a [CancelRequest] if [input] reads as a cancellation, else null.
CancelRequest? detectCancellation(String input) {
  final lower = input.trim().toLowerCase();
  if (lower.isEmpty) return null;

  // Must start with a cancel verb (optionally "please ...").
  final m = RegExp('^(?:please\\s+)?($_cancelVerbs)\\b(.*)\$').firstMatch(lower);
  if (m == null) return null;

  var target = (m.group(2) ?? '').trim();
  // Strip filler so what's left is the reminder's subject keywords.
  target = target
      .replaceFirst(
        RegExp(r'^(the|my|that|this|about|to|for)\s+', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\breminders?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return CancelRequest(target);
}
