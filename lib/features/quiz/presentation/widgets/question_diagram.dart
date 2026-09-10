import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app.dart';
import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../domain/models/content.dart';

/// Renders a question's artwork.
///
/// Diagrams always sit on a fixed light canvas rather than the page
/// background. PRD 6.9 flags that spatial-reasoning art is black line work
/// and would be unreadable on a dark surface; pinning the canvas solves that
/// without asking the content team for transparent variants.
class QuestionDiagram extends StatelessWidget {
  const QuestionDiagram({
    required this.media,
    this.maxHeight = 200,
    super.key,
  });

  final QuestionMedia media;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.language;
    final alt = media.alt.resolveOrNull(language);

    return Semantics(
      image: true,
      label: alt,
      child: GestureDetector(
        onTap: () => _openZoom(context, alt),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.dp(context)),
          decoration: BoxDecoration(
            color: colors.mediaCanvas,
            borderRadius: BorderRadius.circular(AppRadii.md.dp(context)),
            border: Border.all(color: colors.border, width: 1.5),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight.dp(context)),
              child: _content(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (media.isBuiltIn) {
      return _BuiltInDiagram(name: media.builtInKey);
    }
    return CachedNetworkImage(
      imageUrl: media.pathFor(context.language),
      fit: BoxFit.contain,
      placeholder: (context, _) => SizedBox(
        height: 80.dp(context),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      // PRD 6.3 requires a defined fallback rather than an unanswerable
      // question. The quiz screen skips the question; this is the visual
      // marker while that happens.
      errorWidget: (context, _, __) => Padding(
        padding: EdgeInsets.all(AppSpacing.lg.dp(context)),
        child: Text(
          context.l10n.quizImageFailed,
          textAlign: TextAlign.center,
          style: context.text(
            AppTextStyles.caption,
            color: context.colors.mediaCanvasInk,
          ),
        ),
      ),
    );
  }

  void _openZoom(BuildContext context, String? alt) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Container(
                    margin: EdgeInsets.all(AppSpacing.xl.dp(context)),
                    padding: EdgeInsets.all(AppSpacing.xl.dp(context)),
                    decoration: BoxDecoration(
                      color: context.colors.mediaCanvas,
                      borderRadius:
                          BorderRadius.circular(AppRadii.md.dp(context)),
                    ),
                    child: _content(context),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 8,
              child: IconButton(
                onPressed: Navigator.of(context).pop,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: context.l10n.actionClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diagrams drawn in the client rather than fetched.
///
/// Vector art stays crisp at every device scale and costs no round trip. The
/// production bank serves artwork from Supabase Storage; these cover the
/// seed content.
class _BuiltInDiagram extends StatelessWidget {
  const _BuiltInDiagram({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return switch (name) {
      'triangles' => CustomPaint(
          size: Size(180.dp(context), 120.dp(context)),
          painter: _TrianglesPainter(context.colors.mediaCanvasInk),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// The counting-triangles figure: one large triangle split by two lines from
/// its apex, giving three small triangles and six in total.
class _TrianglesPainter extends CustomPainter {
  const _TrianglesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;

    // Drawn against the design's 180x120 box and scaled to whatever the
    // widget was given, so the proportions never drift.
    final sx = size.width / 180;
    final sy = size.height / 120;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final outline = Path()
      ..moveTo(p(90, 8).dx, p(90, 8).dy)
      ..lineTo(p(172, 112).dx, p(172, 112).dy)
      ..lineTo(p(8, 112).dx, p(8, 112).dy)
      ..close();
    canvas.drawPath(outline, paint);

    canvas.drawLine(p(90, 8), p(63, 112), paint);
    canvas.drawLine(p(90, 8), p(117, 112), paint);
  }

  @override
  bool shouldRepaint(_TrianglesPainter oldDelegate) =>
      oldDelegate.color != color;
}
