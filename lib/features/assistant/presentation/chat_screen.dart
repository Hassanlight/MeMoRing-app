/// The primary surface: a ChatGPT-style assistant for creating/cancelling
/// reminders by typing, with optional photo attachments.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/image_store.dart';
import 'package:memoring/core/telemetry.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:memoring/features/announcements/presentation/announcement_banner.dart';
import 'package:memoring/features/assistant/domain/chat_message.dart';
import 'package:memoring/features/assistant/presentation/chat_controller.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/widgets/reminder_card.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _inputFocus = FocusNode();
  final SpeechToText _speech = SpeechToText();
  bool? _speechAvailable; // initialized once, then cached
  String? _pendingImage;
  ReminderIntensity _intensity = ReminderIntensity.low;
  bool _busy = false;
  bool _listening = false;
  bool _hadResult = false;

  @override
  void initState() {
    super.initState();
    // Pre-warm the speech engine so the first mic tap starts instantly.
    // Failures are ignored — the mic tap retries and reports its own errors.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureSpeech().catchError((Object _) => false),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty && _pendingImage == null) return;
    final image = _pendingImage;
    _input.clear();
    setState(() {
      _pendingImage = null;
      _busy = true;
    });
    try {
      await ref
          .read(chatProvider.notifier)
          .send(text, imagePath: image, intensity: _intensity);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      }
    } finally {
      // Always clear busy so the send button can never get stuck spinning.
      if (mounted) setState(() => _busy = false);
    }
    _scrollToEnd();
    // Keep the keyboard up so the next reminder can be typed immediately.
    if (mounted) _inputFocus.requestFocus();
  }

  void _voiceHint(String msg) {
    // Every voice failure also reports home (anonymous, message text only) so
    // the owner dashboard shows the real device error without user screenshots.
    unawaited(Telemetry.log('voice_error', props: {'msg': msg}));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _ensureSpeech() async {
    // Only a SUCCESSFUL init is cached. A failed one (permission not granted
    // yet, recognizer busy) must be retried on the next mic tap, otherwise a
    // bad first attempt disables voice for the whole app session.
    if (_speechAvailable == true) return true;
    final ok = await _speech
        .initialize(
          onStatus: (s) {
            if (s == 'done' && mounted && _listening) {
              setState(() => _listening = false);
              if (!_hadResult) {
                _voiceHint("Didn't catch that — tap the mic and try again.");
              }
            }
          },
          onError: (e) {
            if (mounted && _listening) {
              setState(() => _listening = false);
              if (!_hadResult) {
                // The raw engine error names the real cause (no_match, busy,
                // network, client…) — show it instead of guessing.
                _voiceHint('Mic error: ${e.errorMsg} — tap and try again.');
              }
            }
          },
        )
        .timeout(const Duration(seconds: 10));
    if (ok) _speechAvailable = true;
    return ok;
  }

  /// Every tap must end in visible feedback — either listening starts (red
  /// mic + hint) or a message says exactly why not. A silent tap is a bug.
  Future<void> _toggleMic() async {
    try {
      await _toggleMicInner();
    } on Object catch (e) {
      if (mounted) setState(() => _listening = false);
      _voiceHint('Voice failed to start: $e');
    }
  }

  Future<void> _toggleMicInner() async {
    if (_listening) {
      setState(() => _listening = false);
      await _speech.stop();
      return;
    }
    final mic = await Permission.microphone
        .request()
        .timeout(const Duration(seconds: 30));
    if (!mic.isGranted) {
      _voiceHint(
          'Voice input needs microphone permission — allow it in system Settings.');
      return;
    }
    final available = await _ensureSpeech();
    if (!available) {
      // Permission is fine but the device has no working speech recognizer
      // (e.g. Huawei without Google's speech service).
      _voiceHint('Speech recognition is not available on this device.');
      return;
    }
    _hadResult = false;
    setState(() => _listening = true);
    // Partial results are required for pauseFor's silence detection to work
    // on Android, but the field is only filled from the recognizer's FINAL
    // result — it is re-scored after the speaker finishes and is far more
    // accurate than the live partial guesses (which looked garbled).
    await _speech.listen(
      onResult: (r) {
        if (!r.finalResult) return;
        _hadResult = true;
        _input.text = r.recognizedWords;
        _input.selection =
            TextSelection.collapsed(offset: _input.text.length);
        if (mounted) setState(() => _listening = false);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _attach() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceBlack,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.shinyWhite),
              title: const Text('Take a photo', style: AppTypography.body),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.shinyWhite),
              title: const Text('Choose from gallery', style: AppTypography.body),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    final saved = await persistImage(picked.path);
    if (mounted) setState(() => _pendingImage = saved);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    ref.listen(chatProvider, (_, __) => _scrollToEnd());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memoring', style: AppTypography.heading),
        // Features live in the bottom tabs (Reminders, Life) — header stays clean.
      ),
      body: SafeArea(
        child: Column(
          children: [
            const AnnouncementBanner(),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(AppSpacing.screen),
                itemCount: messages.length,
                itemBuilder: (_, i) => _Bubble(
                  message: messages[i],
                  onPickTime: _pickTimeFor,
                ),
              ),
            ),
            _InputBar(
              controller: _input,
              focusNode: _inputFocus,
              pendingImage: _pendingImage,
              intensity: _intensity,
              onIntensity: (i) => setState(() => _intensity = i),
              listening: _listening,
              onMic: _toggleMic,
              busy: _busy,
              onAttach: _attach,
              onClearImage: () => setState(() => _pendingImage = null),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTimeFor(ChatMessage message) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final fireAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await ref.read(chatProvider.notifier).createAt(
          message.pendingText ?? '',
          fireAt,
          message.imagePath,
          message.intensity,
        );
    _scrollToEnd();
  }
}

class _IntensityChip extends StatelessWidget {
  const _IntensityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.shinyWhite : AppColors.mutedWhite;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.glassTintStrong : AppColors.glassTint,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(label,
                style: AppTypography.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onPickTime});
  final ChatMessage message;
  final void Function(ChatMessage) onPickTime;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatKind.created && message.reminder != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reminder set ✓', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            ReminderCard(
              reminder: message.reminder!,
              onTap: () => context.push('/reminder/${message.reminder!.id}'),
            ),
          ],
        ),
      );
    }

    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isUser ? AppColors.glassTintStrong : AppColors.glassTint,
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  child: Image.file(
                    File(message.imagePath!),
                    height: 140,
                    fit: BoxFit.cover,
                    cacheHeight: 280,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (message.text.isNotEmpty)
                Text(message.text, style: AppTypography.body),
              if (message.kind == ChatKind.needsTime) ...[
                const SizedBox(height: AppSpacing.md),
                GlassButton(
                  label: 'Pick a time',
                  onPressed: () => onPickTime(message),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.pendingImage,
    required this.intensity,
    required this.onIntensity,
    required this.listening,
    required this.onMic,
    required this.busy,
    required this.onAttach,
    required this.onClearImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? pendingImage;
  final ReminderIntensity intensity;
  final ValueChanged<ReminderIntensity> onIntensity;
  final bool listening;
  final VoidCallback onMic;
  final bool busy;
  final VoidCallback onAttach;
  final VoidCallback onClearImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _IntensityChip(
                    label: 'Once',
                    icon: Icons.notifications_none,
                    selected: intensity == ReminderIntensity.low,
                    onTap: () => onIntensity(ReminderIntensity.low),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _IntensityChip(
                    label: 'Ring',
                    icon: Icons.notifications_active_outlined,
                    selected: intensity == ReminderIntensity.medium,
                    onTap: () => onIntensity(ReminderIntensity.medium),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _IntensityChip(
                    label: 'Selfie',
                    icon: Icons.camera_front_outlined,
                    selected: intensity == ReminderIntensity.high,
                    onTap: () => onIntensity(ReminderIntensity.high),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _IntensityChip(
                    label: 'Wake',
                    icon: Icons.calculate_outlined,
                    selected: intensity == ReminderIntensity.wake,
                    onTap: () => onIntensity(ReminderIntensity.wake),
                  ),
                ],
              ),
            ),
          ),
          if (pendingImage != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      child: Image.file(File(pendingImage!),
                          height: 64,
                          width: 64,
                          fit: BoxFit.cover,
                          cacheWidth: 128),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: onClearImage,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.matteBlack,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.shinyWhite),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: onAttach,
                icon: const Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.mutedWhite),
                tooltip: 'Attach photo',
              ),
              IconButton(
                onPressed: onMic,
                icon: Icon(
                  listening ? Icons.mic : Icons.mic_none,
                  color: listening ? AppColors.dangerRed : AppColors.mutedWhite,
                ),
                tooltip: listening ? 'Stop listening' : 'Speak a reminder',
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.body,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  cursorColor: AppColors.shinyWhite,
                  decoration: InputDecoration(
                    hintText: listening
                        ? '🎙 Listening… speak, then pause'
                        : 'Message Memoring…',
                    hintStyle: TextStyle(
                        color: listening
                            ? AppColors.shortTermAccent
                            : AppColors.mutedWhite),
                    filled: true,
                    fillColor: AppColors.glassTint,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: busy ? null : onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.shinyWhite,
                    shape: BoxShape.circle,
                  ),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.matteBlack),
                        )
                      : const Icon(Icons.arrow_upward,
                          color: AppColors.matteBlack),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
