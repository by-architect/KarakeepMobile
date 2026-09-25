import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grouped_section.dart';
import '../../auth/auth_providers.dart';
import '../../bookmarks/presentation/viewmodels/home_feed_view_model.dart';
import '../domain/settings_repository.dart';
import '../settings_providers.dart';
import 'settings_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final _karakeepRepo =
      Uri.parse('https://github.com/karakeep-app/karakeep');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final vm = ref.read(settingsViewModelProvider.notifier);
    final session = ref.watch(currentSessionProvider);
    final showArchived =
        ref.watch(homeFeedViewModelProvider.select((s) => s.showArchived));
    final appVersion = ref.watch(appVersionProvider).value;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GroupedSection(
            label: 'Account',
            children: [
              _AccountRow(
                name: session.user.displayName,
                email: session.user.email,
              ),
              _ValueRow('Server', session.server.baseUrl),
              if (session.serverVersion != null)
                _ValueRow('Server version', session.serverVersion!),
              if (session.server.headers.isNotEmpty)
                _ValueRow(
                  'Custom headers',
                  '${session.server.headers.length}',
                ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'Bookmarks',
            footer: const Text(
              'Karakeep treats archived as read: hiding them turns your '
              'lists into an inbox.',
            ),
            children: [
              SwitchListTile(
                title: const Text('Show archived'),
                value: showArchived,
                activeThumbColor: AppColors.foreground,
                activeTrackColor: AppColors.primary,
                onChanged: ref
                    .read(homeFeedViewModelProvider.notifier)
                    .setShowArchived,
              ),
              SwitchListTile(
                title: const Text('Ask before deleting'),
                subtitle: const Text(
                  'When off, deleting is instant — you still get Undo.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                value: state.confirmDelete,
                activeThumbColor: AppColors.foreground,
                activeTrackColor: AppColors.primary,
                onChanged: vm.setConfirmDelete,
              ),
              _Segmented<ViewerMode>(
                label: 'In-app view',
                value: state.viewerMode,
                options: const {
                  ViewerMode.browser: 'Browser',
                  ViewerMode.reader: 'Reader',
                },
                onChanged: vm.setViewerMode,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Open links in'),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<LinkOpenMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: LinkOpenMode.externalBrowser,
                            label: Text('Browser app'),
                          ),
                          ButtonSegment(
                            value: LinkOpenMode.inAppBrowser,
                            label: Text('In-app viewer'),
                          ),
                        ],
                        selected: {state.linkOpenMode},
                        onSelectionChanged: (s) => vm.setLinkOpenMode(s.single),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'Swipe actions',
            footer: const Text(
              'Swipe a bookmark card sideways on the home and search '
              'screens.',
            ),
            children: [
              _SwipeRow(
                label: 'Swipe right',
                icon: Icons.east_rounded,
                value: state.swipeRight,
                onChanged: vm.setSwipeRight,
              ),
              _SwipeRow(
                label: 'Swipe left',
                icon: Icons.west_rounded,
                value: state.swipeLeft,
                onChanged: vm.setSwipeLeft,
              ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'Storage',
            footer: const Text(
              'Removes downloaded preview images and saved list counts. '
              'Your bookmarks on the server are not touched.',
            ),
            children: [
              ListTile(
                title: const Text('Clear cache'),
                trailing: state.clearingCache
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await vm.clearCache();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Cache cleared')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'About',
            children: [
              _ValueRow('${AppConfig.appName} version', appVersion ?? '…'),
              ListTile(
                title: const Text('Karakeep project'),
                trailing: const Icon(Icons.open_in_new_rounded,
                    size: 18, color: AppColors.muted),
                onTap: () => launchUrl(
                  _karakeepRepo,
                  mode: LaunchMode.externalApplication,
                ),
              ),
              ListTile(
                title: const Text('Open-source licenses'),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConfig.appName,
                  applicationVersion: appVersion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            footer: const Text(
              'Signing out removes the API key from this device. To revoke '
              'it, open Settings → API Keys on the web.',
            ),
            children: [
              ListTile(
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.destructive),
                ),
                onTap: () async {
                  if (await _confirmSignOut(context)) await vm.signOut();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.popover,
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign in again any time. Downloaded images stay cached.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.name, this.email});

  final String name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.popover,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16)),
                if (email != null)
                  Text(
                    email!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final MapEntry(:key, :value) in options.entries)
                  ButtonSegment(value: key, label: Text(value)),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.single),
            ),
          ),
        ],
      ),
    );
  }
}

String swipeActionLabel(SwipeAction action) => switch (action) {
      SwipeAction.none => 'Nothing',
      SwipeAction.favourite => 'Favorite',
      SwipeAction.archive => 'Archive',
      SwipeAction.addToList => 'Add to list',
      SwipeAction.addTag => 'Add tag',
      SwipeAction.delete => 'Delete',
    };

class _SwipeRow extends StatelessWidget {
  const _SwipeRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final SwipeAction value;
  final ValueChanged<SwipeAction> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.mutedForeground),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            swipeActionLabel(value),
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
      onTap: () async {
        final picked = await showModalBottomSheet<SwipeAction>(
          context: context,
          backgroundColor: AppColors.card,
          builder: (context) => SafeArea(
            child: RadioGroup<SwipeAction>(
              groupValue: value,
              onChanged: (a) => Navigator.pop(context, a),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final action in SwipeAction.values)
                    RadioListTile<SwipeAction>(
                      value: action,
                      activeColor: AppColors.primary,
                      title: Text(swipeActionLabel(action)),
                    ),
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
