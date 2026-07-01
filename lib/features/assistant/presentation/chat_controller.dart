/// The conversation brain: turns each typed line into a created/cancelled
/// reminder (or a follow-up), and keeps the message thread.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/core/result.dart';
import 'package:memoring/features/assistant/domain/chat_message.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:memoring/features/scheduler/data/cancellation_parser.dart';
import 'package:memoring/features/scheduler/domain/parsed_reminder.dart';
import 'package:memoring/features/scheduler/presentation/scheduler_providers.dart';

final chatProvider =
    NotifierProvider<ChatController, List<ChatMessage>>(ChatController.new);

class ChatController extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [
        ChatMessage.assistant(
          "Hi! Tell me what to remember — like \"call mom in 2 hours\" or "
          "\"every Monday at 9am standup\". Attach a photo if you like, and say "
          "\"cancel the dentist reminder\" to remove one.",
        ),
      ];

  void _append(ChatMessage m) => state = [...state, m];

  /// Handle one user turn (text and/or photo). Auto-creates or cancels.
  Future<void> send(
    String text, {
    String? imagePath,
    ReminderIntensity intensity = ReminderIntensity.low,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imagePath == null) return;
    _append(ChatMessage.user(trimmed.isEmpty ? '📷 photo' : trimmed,
        imagePath: imagePath));

    // 1. Cancellation intent.
    final cancel = detectCancellation(trimmed);
    if (cancel != null) {
      final deleted =
          await ref.read(remindersControllerProvider).deleteByMatch(cancel.target);
      _append(ChatMessage.assistant(
        deleted != null
            ? 'Done — cancelled "${deleted.text}".'
            : "I couldn't find a matching reminder to cancel. Open the list to "
                "remove it manually.",
      ));
      return;
    }

    // 2. Creation intent.
    final outcome =
        ref.read(parserProvider).parse(trimmed, now: DateTime.now());
    switch (outcome) {
      case ParseSuccess(:final reminder):
        final ctrl = ref.read(remindersControllerProvider);
        final res = await ctrl.create(
          text: reminder.cleanText,
          fireAt: reminder.fireAt,
          recurrence: reminder.recurrence,
          imagePath: imagePath,
          intensity: intensity,
        );
        switch (res) {
          case Ok(:final value):
            _append(ChatMessage.created(value));
            if (ctrl.lastScheduleWarning != null) {
              _append(ChatMessage.assistant('⚠️ ${ctrl.lastScheduleWarning}'));
            }
          case Err(:final message):
            _append(ChatMessage.assistant(message));
        }
      case ParseNeedsTime(:final cleanText):
        _append(ChatMessage.needsTime(cleanText, imagePath, intensity));
      case ParseFailure(:final message):
        _append(ChatMessage.assistant(message));
    }
  }

  /// Complete a needs-time message once the user picks a moment.
  Future<void> createAt(
    String text,
    DateTime fireAt,
    String? imagePath,
    ReminderIntensity intensity,
  ) async {
    final ctrl = ref.read(remindersControllerProvider);
    final res = await ctrl.create(
      text: text,
      fireAt: fireAt,
      recurrence: const Recurrence.none(),
      imagePath: imagePath,
      intensity: intensity,
    );
    switch (res) {
      case Ok(:final value):
        _append(ChatMessage.created(value));
        if (ctrl.lastScheduleWarning != null) {
          _append(ChatMessage.assistant('⚠️ ${ctrl.lastScheduleWarning}'));
        }
      case Err(:final message):
        _append(ChatMessage.assistant(message));
    }
  }
}
