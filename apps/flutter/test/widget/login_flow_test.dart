import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/app.dart';
import 'package:karakeep_client/features/auth/auth_providers.dart';
import 'package:karakeep_client/features/auth/domain/entities/server_info.dart';
import 'package:karakeep_client/features/bookmarks/bookmarks_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../unit/auth/fake_auth_repository.dart';
import '../unit/bookmarks/fakes.dart';

void main() {
  late FakeAuthRepository repo;

  Future<void> pumpApp(WidgetTester tester) async {
    // A phone-sized screen (iPhone 15), so the whole form is on-screen.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          bookmarksRepositoryProvider.overrideWithValue(
            FakeBookmarksRepository(items: {'all': [link('a')]}),
          ),
          homePreferencesProvider.overrideWithValue(InMemoryHomePreferences()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String hint) => find.widgetWithText(TextField, hint);

  FilledButton signInButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  setUp(() => repo = FakeAuthRepository());

  testWidgets('signed-out users land on the login screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Sign in to your Karakeep server'), findsOneWidget);
    expect(signInButton(tester).onPressed, isNull);
  });

  testWidgets('password sign-in reaches home and sign-out returns',
      (tester) async {
    await pumpApp(tester);

    await tester.enterText(field('keep.example.com'), 'keep.example.com');
    await tester.enterText(field('you@example.com'), 'ada@example.com');
    await tester.enterText(field('Required'), 'pw');
    await tester.pump();
    expect(signInButton(tester).onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('All bookmarks'), findsOneWidget);
    expect(find.text('Article a'), findsOneWidget);

    await tester.tap(find.byTooltip('Lists'));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('keep.example.com'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to your Karakeep server'), findsOneWidget);
  });

  testWidgets('Check shows the server version', (tester) async {
    await pumpApp(tester);
    await tester.enterText(field('keep.example.com'), 'keep.example.com');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Karakeep v0.33.0'), findsOneWidget);
  });

  testWidgets('SSO-only server moves to the API key form', (tester) async {
    repo.serverInfo = const ServerInfo(passwordAuthDisabled: true);
    await pumpApp(tester);
    await tester.enterText(field('keep.example.com'), 'keep.example.com');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(field('ak2_…'), findsOneWidget);
    expect(find.textContaining('uses single sign-on'), findsOneWidget);
  });

  testWidgets('Check stays on one line with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);

    final check = find.text('Check');
    final lineHeight =
        tester.renderObject<RenderParagraph>(check).preferredLineHeight;
    expect(tester.getSize(check).height, lessThan(lineHeight * 1.5));
  });

  testWidgets('Karakeep Cloud shortcut fills the address', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Karakeep Cloud'));
    await tester.pump();
    expect(find.text('https://cloud.karakeep.app'), findsOneWidget);
  });
}
