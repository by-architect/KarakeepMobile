import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/app.dart';
import 'package:karakeep_client/features/auth/auth_providers.dart';
import 'package:karakeep_client/features/auth/domain/entities/server_connection.dart';
import 'package:karakeep_client/features/auth/domain/entities/session.dart';
import 'package:karakeep_client/features/bookmarks/bookmarks_providers.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark_list.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:material_ui/material_ui.dart';

import '../unit/auth/fake_auth_repository.dart';
import '../unit/bookmarks/fakes.dart';

void main() {
  late FakeBookmarksRepository bookmarks;
  late InMemoryHomePreferences prefs;

  Future<void> pumpSignedIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository()
      ..stored = const Session(
        server: ServerConnection(baseUrl: 'https://keep.example.com'),
        apiKey: 'ak2_x',
        user: AuthUser(id: 'u1', name: 'Ada'),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          bookmarksRepositoryProvider.overrideWithValue(bookmarks),
          homePreferencesProvider.overrideWithValue(prefs),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Lists'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    bookmarks = FakeBookmarksRepository(
      pageSize: 20,
      lists: const [
        BookmarkList(id: 'L1', name: 'Reading', icon: '📚'),
        BookmarkList(id: 'L2', name: 'Recipes', icon: '🍝', parentId: 'L1'),
      ],
      items: {
        'all': [
          link('a', favourited: true),
          link('b', archived: true),
          link('c'),
        ],
        'favourites': [link('a', favourited: true)],
        'list:L1': [link('r1'), link('r2', archived: true)],
        'list:L2': [link('p1')],
      },
    );
    prefs = InMemoryHomePreferences();
  });

  testWidgets('drawer lists scopes with unarchived / total', (tester) async {
    await pumpSignedIn(tester);
    await openDrawer(tester);

    expect(find.text('All bookmarks'), findsWidgets);
    expect(find.text('2 / 3'), findsOneWidget); // all
    expect(find.text('1 / 1'), findsWidgets); // favourites, Recipes
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget); // Reading
  });

  testWidgets('picking a list shows its unarchived items', (tester) async {
    await pumpSignedIn(tester);
    await openDrawer(tester);
    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();

    expect(find.text('Article r1'), findsOneWidget);
    expect(find.text('Article r2'), findsNothing);
    expect(prefs.scopes.values.single, isA<ListScope>());
  });

  testWidgets('show archived is a remembered filter', (tester) async {
    await pumpSignedIn(tester);
    expect(find.text('Article b'), findsNothing);

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show archived'));
    await tester.pumpAndSettle();

    expect(find.text('Article b'), findsOneWidget);
    expect(prefs.showArchived, isTrue);
  });

  testWidgets('reopening the app restores list and filter', (tester) async {
    prefs
      ..showArchived = true
      ..scopes['https://keep.example.com|u1'] =
          const ListScope(id: 'L1', name: 'Reading', icon: '📚');
    await pumpSignedIn(tester);

    expect(find.text('Reading'), findsOneWidget); // app bar title
    expect(find.text('Article r2'), findsOneWidget); // archived, shown
  });
}
