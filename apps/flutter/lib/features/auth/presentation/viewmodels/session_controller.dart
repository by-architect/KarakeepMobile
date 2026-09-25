import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import '../../domain/entities/session.dart';

/// App-wide "who is signed in". Loading while the keystore is read, then
/// `null` (signed out) or a [Session]. The router redirects off this.
class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => ref.read(authRepositoryProvider).restoreSession();

  void signedIn(Session session) => state = AsyncData(session);

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);
