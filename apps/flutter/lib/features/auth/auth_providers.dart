import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import 'data/datasources/local/session_local_data_source.dart';
import 'data/datasources/remote/auth_remote_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';

/// Composition root for the auth feature. Presentation depends on the
/// [AuthRepository] interface only; tests override this provider.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSource(ref.watch(dioFactoryProvider)),
    local: SessionLocalDataSource(ref.watch(secureStorageProvider)),
  );
});
