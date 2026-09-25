import 'package:flutter_test/flutter_test.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:linkstow/features/bookmarks/domain/search_query.dart';

void main() {
  test('plain text passes through, trimmed', () {
    expect(buildSearchQuery('  rust async  '), 'rust async');
  });

  test('scopes become qualifiers', () {
    expect(buildSearchQuery('x', within: const FavouritesScope()), 'x is:fav');
    expect(
      buildSearchQuery('x', within: const ListScope(id: '1', name: 'Reading', icon: '')),
      'x list:Reading',
    );
    expect(
      buildSearchQuery('x', within: const TagScope(id: '1', name: 'dev-ops')),
      'x #dev-ops',
    );
    expect(buildSearchQuery('x', within: const AllScope()), 'x');
  });

  test('names with spaces are quoted and stray quotes dropped', () {
    expect(
      buildSearchQuery(
        '',
        within: const ListScope(id: '1', name: 'Read "later" soon', icon: ''),
      ),
      'list:"Read later soon"',
    );
  });

  test('hiding archived adds -is:archived, except inside the archive', () {
    expect(buildSearchQuery('x', includeArchived: false), 'x -is:archived');
    expect(
      buildSearchQuery(
        'x',
        within: const ArchivedScope(),
        includeArchived: false,
      ),
      'x is:archived',
    );
  });
}
