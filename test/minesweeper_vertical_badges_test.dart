import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dominik/config/config.dart';
import 'package:dominik/games/minesweeper/region_badges.dart';

void main() {
  group('Region Badges - Vertical & Horizontal Orientations', () {
    testWidgets('RegionMineCounterBadge renders horizontally when isVertical is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RegionMineCounterBadge(
                remainingMines: 10,
                isVertical: false,
              ),
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const ValueKey('region_mine_counter_badge'));
      expect(badgeFinder, findsOneWidget);

      final iconFinder = find.byIcon(MinesweeperConfig.mineCounterIcon);
      final textFinder = find.text('10');

      expect(iconFinder, findsOneWidget);
      expect(textFinder, findsOneWidget);

      final iconRect = tester.getRect(iconFinder);
      final textRect = tester.getRect(textFinder);

      // In horizontal layout, icon is to the left of the text, vertically aligned
      expect(iconRect.right, lessThan(textRect.left));
      expect(iconRect.center.dy, closeTo(textRect.center.dy, 2.0));

      final badgeRect = tester.getRect(badgeFinder);
      expect(badgeRect.height, equals(MinesweeperConfig.headerBadgeHeight));
    });

    testWidgets('RegionMineCounterBadge renders vertically when isVertical is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RegionMineCounterBadge(
                remainingMines: 10,
                isVertical: true,
              ),
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const ValueKey('region_mine_counter_badge'));
      expect(badgeFinder, findsOneWidget);

      final iconFinder = find.byIcon(MinesweeperConfig.mineCounterIcon);
      final textFinder = find.text('10');

      expect(iconFinder, findsOneWidget);
      expect(textFinder, findsOneWidget);

      final badgeRect = tester.getRect(badgeFinder);
      final iconRect = tester.getRect(iconFinder);
      final textRect = tester.getRect(textFinder);

      // Width is fixed matching button width
      expect(badgeRect.width, equals(MinesweeperConfig.headerButtonSize));

      // Icon is above the number
      expect(iconRect.bottom, lessThanOrEqualTo(textRect.top));

      // Both icon and number are horizontally centered in the badge
      expect(iconRect.center.dx, closeTo(badgeRect.center.dx, 1.0));
      expect(textRect.center.dx, closeTo(badgeRect.center.dx, 1.0));
    });

    testWidgets('RegionRankBadge renders horizontally when isVertical is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RegionRankBadge(
                rank: 3,
                isVertical: false,
              ),
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const ValueKey('region_rank_badge'));
      expect(badgeFinder, findsOneWidget);

      final iconFinder = find.byIcon(MinesweeperConfig.rankIcon);
      final textFinder = find.byKey(const ValueKey('region_rank_text'));

      expect(iconFinder, findsOneWidget);
      expect(textFinder, findsOneWidget);

      final iconRect = tester.getRect(iconFinder);
      final textRect = tester.getRect(textFinder);

      // In horizontal layout, icon is to the left of the text, vertically aligned
      expect(iconRect.right, lessThan(textRect.left));
      expect(iconRect.center.dy, closeTo(textRect.center.dy, 2.0));

      final badgeRect = tester.getRect(badgeFinder);
      expect(badgeRect.height, equals(MinesweeperConfig.headerBadgeHeight));
    });

    testWidgets('RegionRankBadge renders vertically when isVertical is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RegionRankBadge(
                rank: 3,
                isVertical: true,
              ),
            ),
          ),
        ),
      );

      final badgeFinder = find.byKey(const ValueKey('region_rank_badge'));
      expect(badgeFinder, findsOneWidget);

      final iconFinder = find.byIcon(MinesweeperConfig.rankIcon);
      final textFinder = find.byKey(const ValueKey('region_rank_text'));

      expect(iconFinder, findsOneWidget);
      expect(textFinder, findsOneWidget);

      final badgeRect = tester.getRect(badgeFinder);
      final iconRect = tester.getRect(iconFinder);
      final textRect = tester.getRect(textFinder);

      // Width is fixed matching button width
      expect(badgeRect.width, equals(MinesweeperConfig.headerButtonSize));

      // Icon is above the number
      expect(iconRect.bottom, lessThanOrEqualTo(textRect.top));

      // Both icon and number are horizontally centered in the badge
      expect(iconRect.center.dx, closeTo(badgeRect.center.dx, 1.0));
      expect(textRect.center.dx, closeTo(badgeRect.center.dx, 1.0));
    });
  });
}
