import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:karakeep_client/features/bookmarks/domain/feed_rules.dart';

import 'fakes.dart';

void main() {
  final plain = link('a');
  final archived = link('b', archived: true);

  test('hidden archive drops archived items, shown archive keeps them', () {
    expect(belongsInFeed(archived, const AllScope(), includeArchived: false),
        isFalse);
    expect(belongsInFeed(archived, const AllScope(), includeArchived: true),
        isTrue);
    expect(belongsInFeed(plain, const AllScope(), includeArchived: false),
        isTrue);
  });

  test('the archive only keeps archived items', () {
    expect(belongsInFeed(plain, const ArchivedScope(), includeArchived: false),
        isFalse);
    expect(
        belongsInFeed(archived, const ArchivedScope(), includeArchived: false),
        isTrue);
  });

  test('favorites and tags drop items that lost them', () {
    expect(
      belongsInFeed(plain, const FavouritesScope(), includeArchived: true),
      isFalse,
    );
    final tagged = plain.copyWith(
      tags: const [BookmarkTag(id: 'T1', name: 'x')],
    );
    const tag = TagScope(id: 'T1', name: 'x');
    expect(belongsInFeed(tagged, tag, includeArchived: true), isTrue);
    expect(belongsInFeed(plain, tag, includeArchived: true), isFalse);
  });

  test('search without a scope still respects the archive filter', () {
    expect(belongsInFeed(archived, null, includeArchived: false), isFalse);
    expect(belongsInFeed(plain, null, includeArchived: false), isTrue);
  });
}
