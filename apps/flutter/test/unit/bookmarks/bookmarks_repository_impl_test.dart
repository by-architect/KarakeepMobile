import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linkstow/core/error/failure.dart';
import 'package:linkstow/core/network/api_client.dart';
import 'package:linkstow/core/network/dio_factory.dart';
import 'package:linkstow/features/bookmarks/data/datasources/remote/bookmarks_remote_data_source.dart';
import 'package:linkstow/features/bookmarks/data/repositories/bookmarks_repository_impl.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:linkstow/features/bookmarks/domain/entities/sort_order.dart';

import '../auth/fake_server.dart';

Map<String, Object?> bookmarkJson(String id, {bool archived = false}) => {
      'id': id,
      'createdAt': '2026-09-01T10:00:00.000Z',
      'title': null,
      'archived': archived,
      'favourited': false,
      'tags': [
        {'id': 't1', 'name': 'dart', 'attachedBy': 'ai'},
      ],
      'content': {
        'type': 'link',
        'url': 'https://www.example.com/$id',
        'title': 'Title $id',
        'description': 'Desc',
        'imageUrl': 'https://cdn.example.com/$id.png',
        'screenshotAssetId': 'shot-$id',
        'favicon': 'https://www.example.com/favicon.ico',
      },
      'assets': [],
    };

Map<String, Object?> trpc(Object? json, [Map<String, Object?>? meta]) => {
      'result': {
        'data': {'json': json, 'meta': ?meta},
      },
    };

void main() {
  late FakeServerAdapter adapter;

  BookmarksRepositoryImpl repo(FakeRoutes routes) {
    adapter = FakeServerAdapter(routes);
    final dio = DioFactory(adapter: adapter).create(
      baseUrl: 'https://keep.example.com',
      apiKey: 'ak2_x',
    );
    return BookmarksRepositoryImpl(
      BookmarksRemoteDataSource(
        ApiClient(
          dio: dio,
          baseUrl: 'https://keep.example.com',
          serverHeaders: const {},
        ),
      ),
    );
  }

  test('deleting a list and a tag', () async {
    final r = repo({
      'DELETE /api/v1/lists/L1': (_) => (status: 204, body: ''),
      'DELETE /api/v1/tags/T1': (_) => (status: 204, body: ''),
    });
    await r.deleteList('L1');
    await r.deleteTag('T1');
    expect(
      adapter.requests.map((o) => '${o.method} ${o.uri.path}'),
      ['DELETE /api/v1/lists/L1', 'DELETE /api/v1/tags/T1'],
    );
  });

  group('getBookmarks', () {
    test('all, archived hidden → REST archived=false', () async {
      final r = repo({
        'GET /api/v1/bookmarks': (_) => (
              status: 200,
              body: {
                'bookmarks': [bookmarkJson('a')],
                'nextCursor': 'a_2026',
              },
            ),
      });
      final page =
          await r.getBookmarks(const AllScope(), includeArchived: false);

      final q = adapter.requests.single.uri.queryParameters;
      expect(q['archived'], 'false');
      expect(q.containsKey('favourited'), isFalse);
      expect(page.nextCursor, 'a_2026');

      final b = page.bookmarks.single;
      expect(b.displayTitle, 'Title a');
      expect(b.tags.single.name, 'dart');
      expect((b.content as LinkContent).domain, 'example.com');
      // Karakeep's priority: screenshot asset beats an external image URL.
      expect(b.previewImage, isA<ServerImage>());
    });

    test('oldest first → sortOrder=asc; newest first sends nothing',
        () async {
      final r = repo({
        'GET /api/v1/bookmarks': (_) =>
            (status: 200, body: {'bookmarks': [], 'nextCursor': null}),
        'GET /api/trpc/bookmarks.getBookmarks': (_) =>
            (status: 200, body: trpc({'bookmarks': [], 'nextCursor': null})),
      });
      await r.getBookmarks(
        const AllScope(),
        includeArchived: false,
        order: SortOrder.oldestFirst,
      );
      await r.getBookmarks(
        const TagScope(id: 'T1', name: 'dart'),
        includeArchived: false,
        order: SortOrder.oldestFirst,
      );
      await r.getBookmarks(const AllScope(), includeArchived: false);

      expect(adapter.requests[0].uri.queryParameters['sortOrder'], 'asc');
      final input = jsonDecode(
        adapter.requests[1].uri.queryParameters['input']!,
      ) as Map;
      expect(input['json'], containsPair('sortOrder', 'asc'));
      expect(
        adapter.requests[2].uri.queryParameters.containsKey('sortOrder'),
        isFalse,
      );
    });

    test('a page waits for changes still on their way', () async {
      final slowPatch = Completer<void>();
      final r = repo({
        'PATCH /api/v1/bookmarks/a': (_) => (status: 200, body: {}),
        'GET /api/v1/bookmarks': (_) =>
            (status: 200, body: {'bookmarks': [], 'nextCursor': null}),
      });
      adapter.hold = (o) => o.method == 'PATCH' ? slowPatch.future : null;

      final archive = r.setArchived('a', true);
      final page = r.getBookmarks(const AllScope(), includeArchived: false);
      await pumpEventQueue();
      // Asking now would get the item back: the server hasn't archived it.
      expect(adapter.requests.map((o) => o.method), ['PATCH']);

      slowPatch.complete();
      await archive;
      await page;
      expect(adapter.requests.map((o) => o.method), ['PATCH', 'GET']);
    });

    test('a failed change doesn\'t hold reads back', () async {
      final r = repo({
        'GET /api/v1/bookmarks': (_) =>
            (status: 200, body: {'bookmarks': [], 'nextCursor': null}),
      }); // no PATCH route: 404
      await expectLater(r.setArchived('a', true), throwsA(isA<Failure>()));
      await r.getBookmarks(const AllScope(), includeArchived: false);
      expect(adapter.requests.map((o) => o.method), ['PATCH', 'GET']);
    });

    test('favourites with archived shown → no archived param', () async {
      final r = repo({
        'GET /api/v1/bookmarks': (_) =>
            (status: 200, body: {'bookmarks': [], 'nextCursor': null}),
      });
      await r.getBookmarks(const FavouritesScope(), includeArchived: true);
      final q = adapter.requests.single.uri.queryParameters;
      expect(q['favourited'], 'true');
      expect(q.containsKey('archived'), isFalse);
    });

    test('list → tRPC with listId, archived and a Date-tagged cursor',
        () async {
      final r = repo({
        'GET /api/trpc/bookmarks.getBookmarks': (_) => (
              status: 200,
              body: trpc(
                {
                  'bookmarks': [bookmarkJson('b')],
                  'nextCursor': {
                    'id': 'b',
                    'createdAt': '2026-09-01T10:00:00.000Z',
                  },
                },
                {
                  'values': {
                    'nextCursor.createdAt': ['Date'],
                  },
                },
              ),
            ),
      });
      const scope = ListScope(id: 'L1', name: 'Reading', icon: '📚');

      final first = await r.getBookmarks(scope, includeArchived: false);
      await r.getBookmarks(
        scope,
        includeArchived: false,
        cursor: first.nextCursor,
      );

      final input1 = jsonDecode(
        adapter.requests[0].uri.queryParameters['input']!,
      ) as Map;
      expect(input1['json'], containsPair('listId', 'L1'));
      expect(input1['json'], containsPair('archived', false));
      expect(input1.containsKey('meta'), isFalse);

      final input2 = jsonDecode(
        adapter.requests[1].uri.queryParameters['input']!,
      ) as Map;
      expect(input2['json']['cursor'], {
        'id': 'b',
        'createdAt': '2026-09-01T10:00:00.000Z',
      });
      expect(input2['meta'], {
        'values': {
          'cursor.createdAt': ['Date'],
        },
      });
    });

    test('a deleted list surfaces as NotFoundFailure', () async {
      final r = repo({});
      await expectLater(
        r.getBookmarks(
          const ListScope(id: 'gone', name: 'x', icon: 'x'),
          includeArchived: true,
        ),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  test('list totals decode the superjson Map', () async {
    final r = repo({
      'GET /api/trpc/lists.stats': (_) => (
            status: 200,
            body: trpc(
              {
                'stats': [
                  ['L1', 5],
                  ['L2', 0],
                ],
              },
              {
                'values': {
                  'stats': ['map'],
                },
              },
            ),
          ),
    });
    expect(await r.getListTotals(), {'L1': 5, 'L2': 0});
  });

  test('countUnarchived pages through with archived=false', () async {
    var page = 0;
    final r = repo({
      'GET /api/v1/bookmarks': (o) {
        page++;
        expect(o.uri.queryParameters['archived'], 'false');
        expect(o.uri.queryParameters['limit'], '100');
        return (
          status: 200,
          body: {
            'bookmarks': [
              for (var i = 0; i < (page == 1 ? 100 : 7); i++)
                bookmarkJson('p$page-$i'),
            ],
            'nextCursor': page == 1 ? 'c1' : null,
          },
        );
      },
    });
    expect(await r.countUnarchived(const FavouritesScope()), 107);
    expect(page, 2);
  });

  test('search sends q and an offset cursor', () async {
    final r = repo({
      'GET /api/v1/bookmarks/search': (_) => (
            status: 200,
            body: {
              'bookmarks': [bookmarkJson('s')],
              'nextCursor': 30,
            },
          ),
    });
    final page = await r.search('rust #dev -is:archived', cursor: '30');
    final q = adapter.requests.single.uri.queryParameters;
    expect(q['q'], 'rust #dev -is:archived');
    expect(q['cursor'], '30');
    expect(page.nextCursor, '30');
    expect(page.bookmarks.single.id, 's');
  });

  test('tags come sorted by usage with their totals', () async {
    final r = repo({
      'GET /api/v1/tags': (o) {
        expect(o.uri.queryParameters['sort'], 'usage');
        return (
          status: 200,
          body: {
            'tags': [
              {
                'id': 'T1',
                'name': 'flutter',
                'numBookmarks': 7,
                'numBookmarksByAttachedType': {'ai': 5, 'human': 2},
              },
            ],
            'nextCursor': null,
          },
        );
      },
    });
    final tag = (await r.getTags()).single;
    expect((tag.id, tag.name, tag.count), ('T1', 'flutter', 7));
  });

  test('a tag feed uses tRPC with tagId', () async {
    final r = repo({
      'GET /api/trpc/bookmarks.getBookmarks': (_) => (
            status: 200,
            body: trpc({'bookmarks': [], 'nextCursor': null}),
          ),
    });
    await r.getBookmarks(
      const TagScope(id: 'T1', name: 'flutter'),
      includeArchived: false,
    );
    final input = jsonDecode(
      adapter.requests.single.uri.queryParameters['input']!,
    ) as Map;
    expect(input['json'], containsPair('tagId', 'T1'));
    expect(input['json'], isNot(contains('listId')));
    expect(input['json'], containsPair('archived', false));
  });
}
