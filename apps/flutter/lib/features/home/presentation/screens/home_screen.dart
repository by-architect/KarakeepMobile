import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/grouped_section.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';

/// Placeholder landing screen until the bookmarks feature exists. Shows the
/// session so sign-in can be verified end to end.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    if (session == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Bookmarks'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GroupedSection(
            label: 'Signed in',
            footer: const Text(
              'Signing out removes the key from this device. To revoke it, '
              'open Settings → API Keys on the web.',
            ),
            children: [
              _InfoRow('Account', session.user.displayName),
              if (session.user.email != null)
                _InfoRow('Email', session.user.email!),
              _InfoRow('Server', session.server.baseUrl),
              if (session.serverVersion != null)
                _InfoRow('Version', session.serverVersion!),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            children: [
              ListTile(
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.destructive),
                ),
                onTap: () =>
                    ref.read(sessionControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Text(label),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}
