import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';

/// A grouped-list row: fixed-width label, then an inline text field.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  static const labelWidth = 92.0;

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 4),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              autofillHints: autofillHints,
              obscureText: obscureText,
              autocorrect: false,
              enableSuggestions: !obscureText,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(hintText: hint),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
