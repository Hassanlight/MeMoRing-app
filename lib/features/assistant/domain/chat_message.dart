/// A single message in the assistant conversation.
library;

import 'package:memoring/features/reminders/domain/reminder.dart';

enum ChatRole { user, assistant }

/// Special rendering for assistant replies.
enum ChatKind {
  text, // plain assistant/user line
  created, // shows the created reminder card
  needsTime, // offers a time picker for [pendingText]
}

final class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.kind = ChatKind.text,
    this.imagePath,
    this.reminder,
    this.pendingText,
  });

  ChatMessage.user(String text, {String? imagePath})
      : this(role: ChatRole.user, text: text, imagePath: imagePath);

  ChatMessage.assistant(String text)
      : this(role: ChatRole.assistant, text: text);

  ChatMessage.created(Reminder reminder)
      : this(
          role: ChatRole.assistant,
          text: 'Reminder set',
          kind: ChatKind.created,
          reminder: reminder,
        );

  ChatMessage.needsTime(String pendingText, String? imagePath)
      : this(
          role: ChatRole.assistant,
          text: "When should I remind you?",
          kind: ChatKind.needsTime,
          pendingText: pendingText,
          imagePath: imagePath,
        );

  final ChatRole role;
  final String text;
  final ChatKind kind;
  final String? imagePath;
  final Reminder? reminder;
  final String? pendingText;
}
