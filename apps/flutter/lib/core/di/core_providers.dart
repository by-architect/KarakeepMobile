import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_factory.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final dioFactoryProvider = Provider<DioFactory>((ref) => const DioFactory());

/// Non-secret device preferences. Created before `runApp` (see main.dart) so
/// reads are synchronous and the first frame already has them.
final sharedPreferencesProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);
