import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../state/login_state.dart';

/// Collapsible key/value editor for headers sent with every request.
class CustomHeadersEditor extends StatelessWidget {
  const CustomHeadersEditor({
    super.key,
    required this.expanded,
    required this.headers,
    required this.headerCount,
    required this.onToggle,
    required this.onAdd,
    required this.onChanged,
    required this.onRemove,
  });

  final bool expanded;
  final List<HeaderEntry> headers;
  final int headerCount;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(int id, {String? name, String? value}) onChanged;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded,
                    size: 18, color: AppColors.mutedForeground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    headerCount == 0
                        ? 'Advanced'
                        : 'Advanced · $headerCount custom '
                            '${headerCount == 1 ? 'header' : 'headers'}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded ? _body() : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, h) in headers.indexed) ...[
                  if (i > 0) const Divider(indent: 16),
                  _HeaderRow(
                    key: ValueKey(h.id),
                    entry: h,
                    onChanged: onChanged,
                    onRemove: () => onRemove(h.id),
                  ),
                ],
                if (headers.isNotEmpty) const Divider(indent: 16),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.add_rounded,
                      color: AppColors.primary),
                  minLeadingWidth: 20,
                  title: const Text(
                    'Add header',
                    style: TextStyle(fontSize: 15, color: AppColors.primary),
                  ),
                  onTap: onAdd,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Sent with every request. Use for servers behind Cloudflare '
              'Access, Authelia or another auth proxy.',
              style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    super.key,
    required this.entry,
    required this.onChanged,
    required this.onRemove,
  });

  final HeaderEntry entry;
  final void Function(int id, {String? name, String? value}) onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 15, color: AppColors.foreground);
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: entry.name,
              style: style,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'Header name'),
              onChanged: (v) => onChanged(entry.id, name: v),
            ),
          ),
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: 20, color: AppColors.border),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: entry.value,
              style: style,
              autocorrect: false,
              obscureText: true,
              enableSuggestions: false,
              decoration: const InputDecoration(hintText: 'Value'),
              onChanged: (v) => onChanged(entry.id, value: v),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove header',
            icon: const Icon(Icons.remove_circle_rounded,
                color: AppColors.destructive, size: 20),
          ),
        ],
      ),
    );
  }
}
