import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../state/login_state.dart';

/// Two-option segmented control in the iOS style of Karakeep's app.
class AuthMethodSwitch extends StatelessWidget {
  const AuthMethodSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.passwordEnabled = true,
  });

  final AuthMethod value;
  final ValueChanged<AuthMethod> onChanged;
  final bool passwordEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          _segment(AuthMethod.password, 'Email & password',
              enabled: passwordEnabled),
          _segment(AuthMethod.apiKey, 'API key'),
        ],
      ),
    );
  }

  Widget _segment(AuthMethod method, String label, {bool enabled = true}) {
    final selected = value == method;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(method) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.input : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill - 2),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: !enabled
                    ? AppColors.muted.withValues(alpha: 0.5)
                    : selected
                        ? AppColors.foreground
                        : AppColors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
