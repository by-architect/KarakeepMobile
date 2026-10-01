import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkstow/app.dart';
import 'package:linkstow/features/auth/auth_providers.dart';
import 'package:linkstow/features/auth/domain/entities/server_connection.dart';
import 'package:linkstow/features/auth/domain/entities/session.dart';
import 'package:linkstow/features/bookmarks/bookmarks_providers.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark_list.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark.dart';
import 'package:linkstow/features/bookmarks/domain/entities/sort_order.dart';
import 'package:linkstow/features/bookmarks/presentation/widgets/add_bookmark.dart';
import 'package:linkstow/features/settings/domain/settings_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../unit/auth/fake_auth_repository.dart';
import '../unit/bookmarks/fakes.dart';
import '../unit/settings/fakes.dart';

void main() {
  late FakeBookmarksRepository bookmarks;
  late InMemoryHomePreferences prefs;
  late InMemorySettings settings;
  late FakeCacheCleaner cleaner;

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
          ...settingsOverrides(settings: settings, cleaner: cleaner),
          imagePickProvider.overrideWithValue(
            () async => (path: '/tmp/cat.jpg', name: 'cat.jpg'),
          ),
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
    bookmarks.tags = const [
      TagSummary(id: 'T1', name: 'flutter', count: 7),
      TagSummary(id: 'T2', name: 'rust', count: 2),
    ];
    bookmarks.items['tag:T1'] = [link('t1'), link('t2', archived: true)];
    prefs = InMemoryHomePreferences();
    settings = InMemorySettings();
    cleaner = FakeCacheCleaner();
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

  testWidgets('oldest first turns the feed around and is remembered',
      (tester) async {
    await pumpSignedIn(tester);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Article a'), lessThan(top('Article c')));

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reverse order'));
    await tester.pumpAndSettle();

    expect(top('Article c'), lessThan(top('Article a')));
    expect(prefs.sort, const FeedSort(reversed: true));
  });

  testWidgets('press and hold a list to delete it; the feed leaves it',
      (tester) async {
    prefs.scopes['https://keep.example.com|u1'] =
        const ListScope(id: 'L1', name: 'Reading', icon: '📚');
    await pumpSignedIn(tester);
    await openDrawer(tester);
    Finder inDrawer(String text) =>
        find.descendant(of: find.byType(Drawer), matching: find.text(text));

    await tester.longPress(inDrawer('Reading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete list'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 📚 Reading?'), findsOneWidget);
    // Recipes sits inside Reading.
    expect(find.textContaining('lists inside it move to the top'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(bookmarks.deletedLists, ['L1']);
    expect(inDrawer('Reading'), findsNothing);
    expect(inDrawer('Recipes'), findsOneWidget);
    expect(prefs.scopes.values.single, const AllScope());
  });

  testWidgets('press and hold a tag to delete it; cancel keeps it',
      (tester) async {
    await pumpSignedIn(tester);
    await openDrawer(tester);

    await tester.longPress(find.text('rust'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete tag'));
    await tester.pumpAndSettle();
    expect(find.text('Delete #rust?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(bookmarks.deletedTags, isEmpty);

    await tester.longPress(find.text('rust'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(bookmarks.deletedTags, ['T2']);
    expect(find.text('rust'), findsNothing);
  });

  group('Add button', () {
    Future<void> add(WidgetTester tester, String option) async {
      // An empty clipboard: the link dialog looks there first.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': ''} : null,
      );
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    testWidgets('adds a link, filling in https://', (tester) async {
      await pumpSignedIn(tester);
      await add(tester, 'Add link');
      await tester.enterText(find.byType(TextField), 'example.org/read');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = bookmarks.created.single.content as LinkContent;
      expect(saved.url, 'https://example.org/read');
      expect(find.text('https://example.org/read'), findsOneWidget); // feed
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('a note added inside a list goes into that list',
        (tester) async {
      prefs.scopes['https://keep.example.com|u1'] =
          const ListScope(id: 'L1', name: 'Reading', icon: '📚');
      await pumpSignedIn(tester);
      await add(tester, 'Add text');
      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final note = bookmarks.created.single;
      expect((note.content as TextContent).text, 'Buy milk');
      expect(bookmarks.listMembership[note.id], {'L1'});
    });

    testWidgets('adds an image from the gallery', (tester) async {
      await pumpSignedIn(tester);
      await add(tester, 'Add image');
      await tester.pumpAndSettle();
      final image = bookmarks.created.single.content as AssetContent;
      expect(image.fileName, 'cat.jpg');
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('a link that isn’t one is refused', (tester) async {
      await pumpSignedIn(tester);
      await add(tester, 'Add link');
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('That doesn’t look like a web address.'), findsOneWidget);
      expect(bookmarks.created, isEmpty);
    });
  });

  testWidgets('sort by title, from the Sort menu', (tester) async {
    bookmarks.items['all'] = [
      link('x', title: 'Zebra'),
      link('y', title: 'apple'),
    ];
    await pumpSignedIn(tester);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Zebra'), lessThan(top('apple')));

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    expect(top('apple'), lessThan(top('Zebra')));
    expect(prefs.sort, const FeedSort(field: SortField.title));
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

  testWidgets('tags sit under lists and filter the feed', (tester) async {
    await pumpSignedIn(tester);
    await openDrawer(tester);

    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('1 / 7'), findsOneWidget); // unarchived / total
    await tester.tap(find.text('flutter'));
    await tester.pumpAndSettle();

    expect(find.text('#flutter'), findsOneWidget); // app bar title
    expect(find.text('Article t1'), findsOneWidget);
    expect(find.text('Article t2'), findsNothing); // archived hidden
  });

  testWidgets('search starts inside the open list', (tester) async {
    prefs.scopes['https://keep.example.com|u1'] =
        const ListScope(id: 'L1', name: 'Reading', icon: '📚');
    bookmarks.searchResults['dart list:Reading -is:archived'] = [
      link('s1', title: 'Found it'),
    ];
    bookmarks.searchResults['dart -is:archived'] = [
      link('s2', title: 'Found everywhere'),
    ];
    await pumpSignedIn(tester);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('In 📚 Reading'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'dart');
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    await tester.pumpAndSettle();
    expect(find.text('Found it'), findsOneWidget);

    // Remove the scope chip: search everywhere.
    await tester.tap(find.byTooltip('Search everywhere'));
    await tester.pumpAndSettle();
    expect(find.text('Found everywhere'), findsOneWidget);
  });

  testWidgets('settings drive the feed filter and are saved', (tester) async {
    await pumpSignedIn(tester);
    await openDrawer(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);

    await tester.tap(find.text('Show archived'));
    await tester.pumpAndSettle();
    expect(prefs.showArchived, isTrue);

    await tester.tap(find.text('Browser app'));
    await tester.pumpAndSettle();
    expect(settings.linkOpenMode, LinkOpenMode.externalBrowser);

    await tester.scrollUntilVisible(find.text('Clear cache'), 200);
    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();
    expect(cleaner.cleared, 1);
    expect(find.text('Cache cleared'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('1.0.0 (1)'), 200);
    expect(find.text('1.0.0 (1)'), findsOneWidget);

    // Back on home, archived items now show.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Article b'), findsOneWidget);
  });
}
