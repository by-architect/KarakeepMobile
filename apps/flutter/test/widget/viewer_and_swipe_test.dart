import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/app.dart';
import 'package:karakeep_client/features/auth/auth_providers.dart';
import 'package:karakeep_client/features/auth/domain/entities/server_connection.dart';
import 'package:karakeep_client/features/auth/domain/entities/session.dart';
import 'package:karakeep_client/features/bookmarks/bookmarks_providers.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark.dart';
import 'package:karakeep_client/features/bookmarks/presentation/widgets/bookmark_page_views.dart';
import 'package:karakeep_client/features/settings/domain/settings_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../unit/auth/fake_auth_repository.dart';
import '../unit/bookmarks/fakes.dart';
import '../unit/settings/fakes.dart';

void main() {
  late FakeBookmarksRepository bookmarks;
  late InMemoryHomePreferences prefs;
  late InMemorySettings settings;

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
          ...settingsOverrides(settings: settings),
          // No platform web views in tests: pages are just labels.
          bookmarkPageBuilderProvider.overrideWithValue(
            (b, mode) => Center(child: Text('page ${b.id} ${mode.name}')),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    bookmarks = FakeBookmarksRepository(
      pageSize: 20,
      items: {
        'all': [
          link('a'),
          link('b'),
          link('c'),
          link('z', archived: true),
        ],
      },
    );
    prefs = InMemoryHomePreferences();
    settings = InMemorySettings();
  });

  group('viewer', () {
    Future<void> openFirst(WidgetTester tester) async {
      await pumpSignedIn(tester);
      await tester.tap(find.text('Article a'));
      await tester.pumpAndSettle();
      expect(find.text('page a browser'), findsOneWidget);
    }

    testWidgets('swipes to the next and previous bookmark', (tester) async {
      await openFirst(tester);

      await tester.fling(find.text('page a browser'), const Offset(-250, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('page b browser'), findsOneWidget);
      expect(find.text('Article b'), findsOneWidget); // title bar

      await tester.fling(find.text('page b browser'), const Offset(250, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('page a browser'), findsOneWidget);
    });

    testWidgets('archive hides it and shows the next; undo brings it back',
        (tester) async {
      await openFirst(tester);

      await tester.tap(find.byTooltip('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('page b browser'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(bookmarks.items['all']!.first.archived, isTrue);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('page a browser'), findsOneWidget);
      expect(bookmarks.items['all']!.first.archived, isFalse);
    });

    testWidgets('with archived shown, archive keeps the page', (tester) async {
      prefs.showArchived = true;
      await openFirst(tester);

      await tester.tap(find.byTooltip('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('page a browser'), findsOneWidget);
      expect(find.byTooltip('Unarchive'), findsOneWidget);
    });

    testWidgets('favorite toggles; delete asks and moves on', (tester) async {
      await openFirst(tester);

      await tester.tap(find.byTooltip('Favorite'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unfavorite'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('page b browser'), findsOneWidget);
      // The server delete waits until Undo is no longer offered.
      expect(bookmarks.deleted, isEmpty);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(bookmarks.deleted, ['a']);
    });

    testWidgets('title menu switches to reader and remembers it',
        (tester) async {
      await openFirst(tester);
      await tester.tap(find.byTooltip('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reader'));
      await tester.pumpAndSettle();
      expect(find.text('page a reader'), findsOneWidget);
      expect(settings.viewerMode, ViewerMode.reader);
    });
  });

  group('card swipes', () {
    testWidgets('right archives (with undo), left favorites', (tester) async {
      await pumpSignedIn(tester);

      await tester.drag(find.text('Article a'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Article a'), findsNothing);
      expect(find.text('Archived'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Article a'), findsOneWidget);

      await tester.drag(find.text('Article b'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Article b'), findsOneWidget); // springs back
      expect(bookmarks.items['all']![1].favourited, isTrue);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget); // card badge
    });

    testWidgets('delete asks first; cancel keeps the card', (tester) async {
      settings.swipeLeft = SwipeAction.delete;
      await pumpSignedIn(tester);

      await tester.drag(find.text('Article c'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Article c'), findsOneWidget);
      expect(bookmarks.deleted, isEmpty);

      await tester.drag(find.text('Article c'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Article c'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(bookmarks.deleted, ['c']);
    });

    testWidgets('undo a delete: nothing is deleted on the server',
        (tester) async {
      settings
        ..swipeLeft = SwipeAction.delete
        ..confirmDelete = false; // no question asked
      await pumpSignedIn(tester);

      await tester.drag(find.text('Article c'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Article c'), findsNothing);
      expect(find.text('Deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Article c'), findsOneWidget);
      expect(bookmarks.deleted, isEmpty);
    });

    testWidgets('favorite has undo too', (tester) async {
      await pumpSignedIn(tester);
      await tester.drag(find.text('Article b'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Added to favorites'), findsOneWidget);
      expect(bookmarks.items['all']![1].favourited, isTrue);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(bookmarks.items['all']![1].favourited, isFalse);
    });

    testWidgets('cards show every tag', (tester) async {
      bookmarks.items['all'] = [
        link('t').copyWith(
          tags: [
            for (var i = 0; i < 9; i++)
              BookmarkTag(id: 't$i', name: 'tag$i'),
          ],
        ),
      ];
      await pumpSignedIn(tester);
      for (var i = 0; i < 9; i++) {
        expect(find.text('#tag$i'), findsOneWidget);
      }
    });
  });

  testWidgets('drawer creates a list and a tag', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(find.byTooltip('Lists'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Later');
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    expect(bookmarks.lists.single.name, 'Later');
    expect(find.text('Later'), findsOneWidget); // now in the drawer

    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tag name'), '#rust');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(bookmarks.tags.single.name, 'rust');
    expect(find.text('rust'), findsOneWidget);
  });

  testWidgets('a smart list needs a query', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(find.byTooltip('Lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Recent');
    await tester.tap(find.text('Smart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    expect(find.text('A smart list needs a search query.'), findsOneWidget);
    expect(bookmarks.lists, isEmpty);
  });

  testWidgets('Tags section shows even when there are no tags',
      (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(find.byTooltip('Lists'));
    await tester.pumpAndSettle();
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('No tags yet.'), findsOneWidget);
  });
}
