import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

enum BannerTone { error, info }

/// A tinted message box, e.g. for form errors.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.error,
  });

  final String message;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      BannerTone.error => AppColors.destructive,
      BannerTone.info => AppColors.primary,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              tone == BannerTone.error
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14, height: 1.35, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
