/// The brain: a deterministic, offline, rule-based natural-language time parser.
///
/// Pure (no I/O, `now` injected) so every rule is trivially unit-testable.
/// It never executes input — only regex/keyword matching — so it is safe against
/// hostile text. Returns local wall-clock times; persistence converts to UTC.
library;

import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/scheduler/domain/parsed_reminder.dart';
import 'package:memoring/features/scheduler/domain/time_intent_parser.dart';

/// Default fire time when a date is given without a time of day.
const int _defaultHour = 9;

class RuleBasedTimeIntentParser implements TimeIntentParser {
  const RuleBasedTimeIntentParser();

  static const Map<String, int> _weekdays = {
    'monday': 1, 'mon': 1,
    'tuesday': 2, 'tues': 2, 'tue': 2,
    'wednesday': 3, 'wed': 3,
    'thursday': 4, 'thurs': 4, 'thu': 4,
    'friday': 5, 'fri': 5,
    'saturday': 6, 'sat': 6,
    'sunday': 7, 'sun': 7,
  };

  static const Map<String, int> _months = {
    'january': 1, 'jan': 1,
    'february': 2, 'feb': 2,
    'march': 3, 'mar': 3,
    'april': 4, 'apr': 4,
    'may': 5,
    'june': 6, 'jun': 6,
    'july': 7, 'jul': 7,
    'august': 8, 'aug': 8,
    'september': 9, 'sept': 9, 'sep': 9,
    'october': 10, 'oct': 10,
    'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  // Longer alternatives first so the regex prefers "tuesday" over "tue".
  static const String _weekdayAlt =
      'monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thu|'
      'friday|fri|saturday|sat|sunday|sun';
  static const String _monthAlt =
      'january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|'
      'august|aug|september|sept|sep|october|oct|november|nov|december|dec';

  @override
  ParseOutcome parse(String input, {required DateTime now}) {
    final original = input.trim();
    if (original.isEmpty) {
      return const ParseFailure(
        ParseFailureReason.empty,
        'Type something to be reminded about.',
      );
    }
    if (original.length > kMaxReminderInputLength) {
      return const ParseFailure(
        ParseFailureReason.tooLong,
        'That reminder is too long. Keep it under $kMaxReminderInputLength characters.',
      );
    }

    final lower = original.toLowerCase();
    var working = original;
    var recurrence = const Recurrence.none();
    DateTime? fireAt;

    // 1. Recurrence.
    final rec = _matchRecurrence(lower);
    if (rec != null) {
      recurrence = rec.recurrence;
      working = _strip(working, rec.matched);
    }

    // 2. Relative duration ("in 2 hours") — mutually exclusive with recurrence.
    final dur = _matchDuration(lower);
    if (dur != null && !recurrence.isRecurring) {
      fireAt = _addDuration(now, dur.amount, dur.unit);
      working = _strip(working, dur.matched);
    }

    // 3. Absolute / named date + time of day.
    if (fireAt == null) {
      if (RegExp(r'\btonight\b').hasMatch(lower)) {
        fireAt = DateTime(now.year, now.month, now.day, 20);
        working = _strip(working, 'tonight');
      } else {
        final dateMatch = _matchDate(lower, now);
        var remaining = lower;
        if (dateMatch != null) remaining = _strip(remaining, dateMatch.matched);
        final tod = _matchTimeOfDay(remaining);

        if (dateMatch != null) {
          fireAt = _combine(dateMatch.date, tod);
          fireAt = _applyRoll(fireAt, dateMatch.roll, now);
          working = _strip(working, dateMatch.matched);
          if (tod != null) working = _strip(working, tod.matched);
        } else if (tod != null) {
          fireAt = _nextUpcomingTime(now, tod);
          working = _strip(working, tod.matched);
        }
      }
    }

    // 4. Recurrence with no explicit date/time → first occurrence at 09:00.
    if (recurrence.isRecurring && fireAt == null) {
      fireAt = _firstRecurrence(now, recurrence, const _TimeOfDay(_defaultHour, 0, true));
    }

    // 5. No time at all → ask the user; never guess.
    if (fireAt == null) {
      return ParseNeedsTime(_clean(working, original));
    }

    // 6. Reject the past.
    if (!fireAt.isAfter(now)) {
      return const ParseFailure(
        ParseFailureReason.pastTime,
        'That time has already passed. Try a future time.',
      );
    }

    return ParseSuccess(
      ParsedReminder(
        cleanText: _clean(working, original),
        fireAt: fireAt,
        recurrence: recurrence,
      ),
    );
  }

  // --- Recurrence -----------------------------------------------------------

  _RecMatch? _matchRecurrence(String s) {
    final everyWd =
        RegExp('\\bevery\\s+($_weekdayAlt)\\b').firstMatch(s);
    if (everyWd != null) {
      return _RecMatch(
        Recurrence(RecurrenceType.weekly, weekday: _weekdays[everyWd.group(1)!]),
        everyWd.group(0)!,
      );
    }
    final patterns = <RegExp, Recurrence>{
      RegExp(r'\b(daily|every\s*day)\b'): const Recurrence(RecurrenceType.daily),
      RegExp(r'\b(weekly|every\s+week)\b'): const Recurrence(RecurrenceType.weekly),
      RegExp(r'\b(monthly|every\s+month)\b'): const Recurrence(RecurrenceType.monthly),
      RegExp(r'\b(yearly|annually|every\s+year)\b'): const Recurrence(RecurrenceType.yearly),
    };
    for (final entry in patterns.entries) {
      final m = entry.key.firstMatch(s);
      if (m != null) return _RecMatch(entry.value, m.group(0)!);
    }
    return null;
  }

  // --- Duration -------------------------------------------------------------

  _DurationMatch? _matchDuration(String s) {
    final m = RegExp(
      r'\bin\s+(\d+|an?)\s+(minute|min|hour|hr|day|week|month|year)s?\b',
    ).firstMatch(s);
    if (m == null) return null;
    final raw = m.group(1)!;
    final amount = (raw == 'a' || raw == 'an') ? 1 : int.parse(raw);
    return _DurationMatch(amount, m.group(2)!, m.group(0)!);
  }

  DateTime _addDuration(DateTime now, int amount, String unit) {
    switch (unit) {
      case 'minute':
      case 'min':
        return now.add(Duration(minutes: amount));
      case 'hour':
      case 'hr':
        return now.add(Duration(hours: amount));
      case 'day':
        return now.add(Duration(days: amount));
      case 'week':
        return now.add(Duration(days: amount * 7));
      case 'month':
        return _addMonths(now, amount);
      case 'year':
        return _addMonths(now, amount * 12);
      default:
        return now;
    }
  }

  // --- Date -----------------------------------------------------------------

  _DateMatch? _matchDate(String s, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    final tomorrow = RegExp(r'\btomorrow\b').firstMatch(s);
    if (tomorrow != null) {
      return _DateMatch(today.add(const Duration(days: 1)), tomorrow.group(0)!, _Roll.none);
    }
    final todayM = RegExp(r'\btoday\b').firstMatch(s);
    if (todayM != null) {
      return _DateMatch(today, todayM.group(0)!, _Roll.none);
    }
    final nextWd = RegExp('\\bnext\\s+($_weekdayAlt)\\b').firstMatch(s);
    if (nextWd != null) {
      final wd = _weekdays[nextWd.group(1)!]!;
      return _DateMatch(_nextWeekday(today, now.weekday, wd, forceNext: true), nextWd.group(0)!, _Roll.none);
    }
    final bareWd = RegExp('\\b($_weekdayAlt)\\b').firstMatch(s);
    if (bareWd != null) {
      final wd = _weekdays[bareWd.group(1)!]!;
      return _DateMatch(_nextWeekday(today, now.weekday, wd, forceNext: false), bareWd.group(0)!, _Roll.weekly);
    }
    final monthDay =
        RegExp('\\b(?:on\\s+)?($_monthAlt)\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b').firstMatch(s);
    if (monthDay != null) {
      final month = _months[monthDay.group(1)!]!;
      final day = int.parse(monthDay.group(2)!);
      if (day >= 1 && day <= 31) {
        return _DateMatch(DateTime(now.year, month, day), monthDay.group(0)!, _Roll.yearly);
      }
    }
    return null;
  }

  DateTime _nextWeekday(DateTime today, int nowWeekday, int target, {required bool forceNext}) {
    var diff = (target - nowWeekday) % 7;
    if (diff < 0) diff += 7;
    if (forceNext && diff == 0) diff = 7;
    return today.add(Duration(days: diff));
  }

  DateTime _applyRoll(DateTime fireAt, _Roll roll, DateTime now) {
    var result = fireAt;
    switch (roll) {
      case _Roll.weekly:
        while (!result.isAfter(now)) {
          result = result.add(const Duration(days: 7));
        }
      case _Roll.yearly:
        while (!result.isAfter(now)) {
          result = _addMonths(result, 12);
        }
      case _Roll.none:
        break;
    }
    return result;
  }

  // --- Time of day ----------------------------------------------------------

  _TimeOfDay? _matchTimeOfDay(String s) {
    final candidates = <_TimeOfDay>[];

    final named = RegExp(r'\b(noon|midnight)\b').firstMatch(s);
    if (named != null) {
      candidates.add(named.group(1) == 'noon'
          ? _TimeOfDay(12, 0, true, named.group(0)!)
          : _TimeOfDay(0, 0, true, named.group(0)!));
    }
    final atTime = RegExp(r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b').firstMatch(s);
    if (atTime != null) {
      final t = _buildTod(atTime, includeBare: true);
      if (t != null) candidates.add(t);
    }
    final meridiem = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b').firstMatch(s);
    if (meridiem != null) {
      final t = _buildTod(meridiem, includeBare: false);
      if (t != null) candidates.add(t);
    }
    final colon = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(s);
    if (colon != null) {
      final t = _buildTodParts(int.parse(colon.group(1)!), int.parse(colon.group(2)!), null, colon.group(0)!);
      if (t != null) candidates.add(t);
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => s.indexOf(a.matched).compareTo(s.indexOf(b.matched)));
    return candidates.first;
  }

  _TimeOfDay? _buildTod(RegExpMatch m, {required bool includeBare}) {
    final hour = int.parse(m.group(1)!);
    final minute = m.group(2) != null ? int.parse(m.group(2)!) : 0;
    final ampm = m.group(3);
    if (ampm == null && !includeBare) return null;
    return _buildTodParts(hour, minute, ampm, m.group(0)!);
  }

  _TimeOfDay? _buildTodParts(int hour, int minute, String? ampm, String matched) {
    if (minute < 0 || minute > 59) return null;
    if (ampm == 'am') {
      if (hour < 1 || hour > 12) return null;
      return _TimeOfDay(hour == 12 ? 0 : hour, minute, true, matched);
    }
    if (ampm == 'pm') {
      if (hour < 1 || hour > 12) return null;
      return _TimeOfDay(hour == 12 ? 12 : hour + 12, minute, true, matched);
    }
    if (hour < 0 || hour > 23) return null;
    return _TimeOfDay(hour, minute, hour > 12, matched);
  }

  DateTime _combine(DateTime date, _TimeOfDay? tod) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      tod?.hour ?? _defaultHour,
      tod?.minute ?? 0,
    );
  }

  DateTime _nextUpcomingTime(DateTime now, _TimeOfDay tod) {
    DateTime atHour(int hour) {
      var c = DateTime(now.year, now.month, now.day, hour, tod.minute);
      if (!c.isAfter(now)) c = c.add(const Duration(days: 1));
      return c;
    }

    if (tod.meridiemKnown) return atHour(tod.hour);
    final candidates = <DateTime>{atHour(tod.hour), if (tod.hour < 12) atHour(tod.hour + 12)}.toList()
      ..sort();
    return candidates.first;
  }

  DateTime _firstRecurrence(DateTime now, Recurrence rec, _TimeOfDay tod) {
    switch (rec.type) {
      case RecurrenceType.daily:
        var c = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
        if (!c.isAfter(now)) c = c.add(const Duration(days: 1));
        return c;
      case RecurrenceType.weekly:
        final wd = rec.weekday ?? now.weekday;
        final base = _nextWeekday(DateTime(now.year, now.month, now.day), now.weekday, wd, forceNext: false);
        var c = DateTime(base.year, base.month, base.day, tod.hour, tod.minute);
        if (!c.isAfter(now)) c = c.add(const Duration(days: 7));
        return c;
      case RecurrenceType.monthly:
        var c = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
        if (!c.isAfter(now)) c = _addMonths(c, 1);
        return c;
      case RecurrenceType.yearly:
        var c = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
        if (!c.isAfter(now)) c = _addMonths(c, 12);
        return c;
      case RecurrenceType.none:
        return now;
    }
  }

  // --- Text cleanup ---------------------------------------------------------

  String _strip(String source, String matchLower) {
    if (matchLower.isEmpty) return source;
    final i = source.toLowerCase().indexOf(matchLower.toLowerCase());
    if (i < 0) return source;
    return source.replaceRange(i, i + matchLower.length, ' ');
  }

  String _clean(String text, String fallback) {
    var r = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    r = r.replaceFirst(
      RegExp(r'^(remind|remember)(\s+me)?(\s+to)?\s+', caseSensitive: false),
      '',
    );
    r = r.replaceFirst(RegExp(r'^(to|that|about)\s+', caseSensitive: false), '');
    r = r.replaceFirst(RegExp(r'\s+(on|at|in|by|every)$', caseSensitive: false), '');
    r = r.trim();
    return r.isEmpty ? fallback : r;
  }

  // --- Date math ------------------------------------------------------------

  static DateTime _addMonths(DateTime d, int months) {
    var year = d.year;
    var month = d.month + months;
    year += (month - 1) ~/ 12;
    month = (month - 1) % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day <= lastDay ? d.day : lastDay;
    return DateTime(year, month, day, d.hour, d.minute);
  }
}

class _TimeOfDay {
  const _TimeOfDay(this.hour, this.minute, this.meridiemKnown, [this.matched = '']);
  final int hour;
  final int minute;
  final bool meridiemKnown;
  final String matched;
}

class _DurationMatch {
  const _DurationMatch(this.amount, this.unit, this.matched);
  final int amount;
  final String unit;
  final String matched;
}

class _RecMatch {
  const _RecMatch(this.recurrence, this.matched);
  final Recurrence recurrence;
  final String matched;
}

enum _Roll { none, weekly, yearly }

class _DateMatch {
  const _DateMatch(this.date, this.matched, this.roll);
  final DateTime date;
  final String matched;
  final _Roll roll;
}
