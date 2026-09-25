import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// An inset, rounded group of rows with hairline separators — the grouped
/// list look of Karakeep's mobile app.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.label,
    this.footer,
    required this.children,
  });

  final String? label;
  final Widget? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(indent: 16));
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              label!.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.4,
                color: AppColors.muted,
              ),
            ),
          ),
        // Material (not a DecoratedBox) so tappable rows show their ripple.
        Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.muted,
              ),
              child: footer!,
            ),
          ),
      ],
    );
  }
}
