import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../state/login_state.dart';

/// Trailing indicator inside the server row.
class ServerStatusIndicator extends StatelessWidget {
  const ServerStatusIndicator({
    super.key,
    required this.status,
    required this.onCheck,
  });

  final ServerStatus status;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    // Sized by content, not a fixed width: device fonts and text scaling
    // make "Check" wider than on the design screen.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
      child: Center(
        child: switch (status) {
          ServerStatus.checking => const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ServerStatus.reachable => const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.success,
              semanticLabel: 'Server reachable',
            ),
          ServerStatus.unchecked || ServerStatus.failed => TextButton(
              onPressed: onCheck,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Check', maxLines: 1, softWrap: false),
            ),
        },
      ),
    );
  }
}

/// The line under the server group: connection result or a hint.
class ServerStatusFooter extends StatelessWidget {
  const ServerStatusFooter({
    super.key,
    required this.state,
    required this.onUseCloud,
  });

  final LoginState state;
  final VoidCallback onUseCloud;

  @override
  Widget build(BuildContext context) {
    switch (state.serverStatus) {
      case ServerStatus.reachable:
        final version = state.serverInfo?.version;
        return Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Connected',
                style: TextStyle(color: AppColors.success),
              ),
              if (version != null && version != 'unknown')
                TextSpan(text: ' · Karakeep ${_prettyVersion(version)}'),
              if (state.serverInfo?.demoMode ?? false)
                const TextSpan(text: ' · demo (read-only)'),
            ],
          ),
        );
      case ServerStatus.failed:
        return Text(
          state.serverError ?? '',
          style: const TextStyle(color: AppColors.destructive),
        );
      case ServerStatus.checking:
        return const Text('Checking server…');
      case ServerStatus.unchecked:
        return Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Your self-hosted Karakeep address. Or use '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: onUseCloud,
                  child: const Text(
                    'Karakeep Cloud',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        );
    }
  }

  static String _prettyVersion(String v) =>
      RegExp(r'^\d').hasMatch(v) ? 'v$v' : v;
}
