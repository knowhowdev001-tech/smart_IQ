import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';

/// The Practice tab: the category list, as an entry point to drilling.
///
/// Home shows the same categories as a compact grid. This is the list form,
/// with room for the question counts that help a user choose where to spend
/// a limited daily allowance.
class PracticeHubScreen extends ConsumerWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final language = context.language;
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: [
          BrandHeader(
            child: ContentColumn(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.navPractice,
                  style: context.text(
                    AppTextStyles.title,
                    weight: 700,
                    color: colors.brandInk,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: categories.when(
              loading: () => const SiqLoader(),
              error: (_, __) => SiqMessageState.offline(
                context,
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
              data: (items) => ContentColumn(
                child: ListView.separated(
                  padding: EdgeInsets.all(AppSpacing.gutter.dp(context)),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: AppSpacing.sm.dp(context)),
                  itemBuilder: (context, index) {
                    final category = items[index];
                    return SiqCard(
                      onTap: () => context.push(
                        '${Routes.practiceCategory}?category=${category.key}',
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.dp(context),
                        vertical: 14.dp(context),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.name.resolve(language),
                                  style: context.text(
                                    AppTextStyles.body,
                                    weight: 700,
                                    color: colors.ink,
                                  ),
                                ),
                                SizedBox(height: 2.dp(context)),
                                Text(
                                  category.meta.resolve(language),
                                  style: context.text(
                                    AppTextStyles.captionSmall,
                                    color: colors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18.dp(context),
                            color: colors.inkFaint,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
