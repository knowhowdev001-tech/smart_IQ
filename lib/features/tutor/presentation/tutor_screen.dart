import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/chat.dart';
import '../../billing/presentation/plan_sheet.dart';

/// The AI tutor.
///
/// The app is a thin client over an external endpoint reached through an
/// Edge Function proxy (PRD 4.5). It never calls the model directly, never
/// enforces the message limit itself, and renders whatever the endpoint
/// sends — streaming or not.
class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key});

  @override
  ConsumerState<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends ConsumerState<TutorScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<ChatMessage> _messages = [];
  String? _threadId;
  bool _sending = false;
  bool _exhausted = false;
  String? _error;
  StreamSubscription<ChatMessage>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    final repository = ref.read(tutorRepositoryProvider);
    final language = ref.read(languageProvider);

    _threadId ??= (await repository.createThread()).id;

    setState(() {
      _messages.add(
        ChatMessage(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.user,
          content: text,
          createdAt: DateTime.now(),
          language: language,
        ),
      );
      _input.clear();
      _sending = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      // A streamed reply replaces the previous partial each event, so the
      // bubble grows in place rather than the list filling with fragments.
      await for (final message in repository.send(
        threadId: _threadId!,
        content: text,
        language: language,
      )) {
        if (!mounted) return;
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index == -1) {
            _messages.add(message);
          } else {
            _messages[index] = message;
          }
        });
        _scrollToEnd();
      }
      await ref.read(entitlementProvider.notifier).syncUsage();
    } on QuotaExceededException {
      if (mounted) setState(() => _exhausted = true);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.tutorError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _newThread() {
    setState(() {
      _messages.clear();
      _threadId = null;
      _exhausted = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final entitlement = ref.watch(currentEntitlementProvider);
    final limits = entitlement.limits;
    final used = entitlement.usage.aiMessagesToday;

    return Scaffold(
      backgroundColor: colors.page,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          BrandAppBar(
            title: l10n.tutorTitle,
            subtitle: l10n.tutorQuotaLine(used, '${limits.aiMessagesPerDay}'),
            trailing: TextButton(
              onPressed: _messages.isEmpty ? null : _newThread,
              child: Text(
                l10n.tutorNewThread,
                style: context.text(
                  AppTextStyles.caption,
                  weight: 700,
                  color: colors.brandInk,
                ),
              ),
            ),
          ),
          Expanded(
            child: ContentColumn(
              child: _messages.isEmpty
                  ? _EmptyState(onSuggestion: (text) {
                      _input.text = text;
                      _send();
                    })
                  : ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg.dp(context),
                        vertical: AppSpacing.lg.dp(context),
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) =>
                          _Bubble(message: _messages[index]),
                    ),
            ),
          ),
          if (_exhausted)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.dp(context),
                0,
                AppSpacing.lg.dp(context),
                AppSpacing.md.dp(context),
              ),
              child: ContentColumn(
                child: LockedBanner(
                  title: l10n.tutorExhaustedTitle,
                  body: l10n.tutorExhaustedBody('${limits.aiMessagesPerDay}'),
                  onUpgrade: () => showPlanSheet(context),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.dp(context),
                vertical: AppSpacing.sm.dp(context),
              ),
              child: Text(
                _error!,
                style: context.text(
                  AppTextStyles.caption,
                  color: colors.dangerInk,
                ),
              ),
            ),
          _Composer(
            controller: _input,
            sending: _sending,
            enabled: !_exhausted,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    // Suggestions map to the four tutor capabilities in PRD 6.4: explain,
    // hint, follow-up and generate a practice set.
    final suggestions = [
      'Explain ratio and proportion with an example',
      'Give me a hint for time and work problems',
      'Make me a 10-question set on percentages',
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.gutter.dp(context)),
      child: Column(
        children: [
          SizedBox(height: AppSpacing.xxl.dp(context)),
          Container(
            width: 56.dp(context),
            height: 56.dp(context),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 26.dp(context),
              color: colors.accentSoftInk,
            ),
          ),
          SizedBox(height: AppSpacing.lg.dp(context)),
          Text(
            l10n.tutorEmptyTitle,
            style: context.text(
              AppTextStyles.titleSmall,
              weight: 700,
              color: colors.ink,
            ),
          ),
          SizedBox(height: AppSpacing.sm.dp(context)),
          Text(
            l10n.tutorEmptyBody,
            textAlign: TextAlign.center,
            style: context.text(
              AppTextStyles.bodySmall,
              color: colors.inkMuted,
            ),
          ),
          SizedBox(height: AppSpacing.xl.dp(context)),
          for (final suggestion in suggestions)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm.dp(context)),
              child: SiqCard(
                onTap: () => onSuggestion(suggestion),
                radius: AppRadii.md,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        suggestion,
                        style: context.text(
                          AppTextStyles.bodySmall,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.north_east_rounded,
                      size: 15.dp(context),
                      color: colors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.dp(context)),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 13.dp(context),
                vertical: 11.dp(context),
              ),
              decoration: BoxDecoration(
                color: isUser ? colors.accent : colors.surfaceMuted,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.md.dp(context)),
                  topRight: Radius.circular(AppRadii.md.dp(context)),
                  bottomLeft: Radius.circular(
                    isUser ? AppRadii.md.dp(context) : 4.dp(context),
                  ),
                  bottomRight: Radius.circular(
                    isUser ? 4.dp(context) : AppRadii.md.dp(context),
                  ),
                ),
              ),
              child: Text(
                message.content,
                style: context.text(
                  AppTextStyles.bodySmall,
                  color: isUser ? colors.accentInk : colors.ink,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      color: colors.page,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.dp(context),
        AppSpacing.sm.dp(context),
        AppSpacing.lg.dp(context),
        AppSpacing.sm.dp(context),
      ),
      child: SafeArea(
        top: false,
        child: ContentColumn(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled && !sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: context.text(
                    AppTextStyles.bodySmall,
                    color: colors.ink,
                  ),
                  cursorColor: colors.accent,
                  decoration: InputDecoration(
                    hintText: context.l10n.tutorInputHint,
                    hintStyle: context.text(
                      AppTextStyles.bodySmall,
                      color: colors.inkMuted,
                    ),
                    filled: true,
                    fillColor: colors.surfaceSunken,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg.dp(context),
                      vertical: 12.dp(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22.dp(context)),
                      borderSide: BorderSide(color: colors.border, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22.dp(context)),
                      borderSide: BorderSide(color: colors.border, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22.dp(context)),
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm.dp(context)),
              Material(
                color: enabled ? colors.accent : colors.border,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: enabled && !sending ? onSend : null,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 42.dp(context),
                    height: 42.dp(context),
                    child: sending
                        ? Padding(
                            padding: EdgeInsets.all(12.dp(context)),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(colors.accentInk),
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            size: 18.dp(context),
                            color: colors.accentInk,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
