import 'package:flutter/material.dart';

import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// One choice in a [SiqSegmented].
@immutable
class SiqSegment<T> {
  const SiqSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// A row of small pills where exactly one is selected, such as the range the
/// results dashboard is showing.
///
/// Material's [SegmentedButton] carries its own shape, height and selected
/// check; this matches the chip metrics the rest of the app already uses
/// (28dp tall, `captionSmall` at weight 700) so the row reads as part of the
/// same set as every other chip.
class SiqSegmented<T> extends StatelessWidget {
  const SiqSegmented({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<SiqSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final segment in segments)
          Padding(
            padding: EdgeInsets.only(
              left: segment == segments.first ? 0 : 6.dp(context),
            ),
            child: _Pill(
              label: segment.label,
              selected: segment.value == value,
              onTap: () => onChanged(segment.value),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final height = 28.0.dp(context);
    final radius = BorderRadius.circular(height / 2);

    final background = selected ? colors.accent : colors.surface;
    final foreground = selected ? colors.accentInk : colors.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: selected ? null : onTap,
          borderRadius: radius,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: selected
                  ? null
                  : Border.all(color: colors.border, width: 1.5),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.dp(context)),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: context.text(
                    AppTextStyles.captionSmall,
                    weight: 700,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
