import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/domain/reward_engine.dart';
import 'package:spendwise/models/expense.dart';
import 'package:spendwise/main.dart'
    show allQuests, allChallenges, ChallengePeriod;

void main() {
  final now = DateTime(2026, 10, 27); // Tuesday
  Expense e(int day, {String category = 'Food & Dining'}) => Expense(
    id: '$day-$category',
    description: 'Lunch',
    amount: 10,
    category: category,
    date: DateTime(2026, 10, day),
  );
  RewardEvaluation evaluate(
    List<Expense> expenses, {
    RewardEvaluation? previous,
    double budget = 0,
    DateTime? date,
  }) => RewardEngine.evaluate(
    expenses: expenses,
    now: date ?? now,
    monthlyBudget: budget,
    hasCategoryBudget: false,
    categoryCount: 8,
    xp: previous?.xp ?? 0,
    coins: previous?.coins ?? 0,
    bestStreak: previous?.bestStreak ?? 0,
    completedQuests: previous?.quests ?? {},
    earnedBadges: previous?.badges ?? {},
    challengeClaims: previous?.challenges ?? {},
    questRewards: {for (final q in allQuests) q.id: (xp: q.xp, coins: q.coins)},
    challengeRules: {
      for (final c in allChallenges)
        c.id: (
          goal: c.goal,
          daily: c.period == ChallengePeriod.daily,
          xp: c.xp,
          coins: c.coins,
        ),
    },
  );

  test('exactly 10000 is a valid configured budget; zero is unset', () {
    expect(
      evaluate([], budget: 10000).newQuests,
      contains('set_monthly_budget'),
    );
    expect(evaluate([]).newQuests, isNot(contains('set_monthly_budget')));
  });
  test('repeated evaluation cannot award quests or daily challenges twice', () {
    final first = evaluate([e(27)]);
    final again = evaluate([e(27)], previous: first);
    expect(first.newChallenges, contains('daily_tracker'));
    expect(again.newChallenges, isEmpty);
    expect(again.newQuests, isEmpty);
    expect(again.xp, first.xp);
    expect(again.coins, first.coins);
  });
  test('future days cannot complete weekly consistency', () {
    final progress = RewardEngine.challengeProgress([
      e(26),
      e(27),
      e(28),
      e(29),
      e(30),
    ], now);
    expect(progress['weekly_consistency'], 2);
    expect(
      evaluate([e(26), e(27), e(28), e(29), e(30)]).newChallenges,
      isNot(contains('weekly_consistency')),
    );
  });
  test('new day earns a new daily reward but keeps old completion markers', () {
    final first = evaluate([e(27)]);
    final next = evaluate(
      [e(27), e(28)],
      previous: first,
      date: DateTime(2026, 10, 28),
    );
    expect(next.newChallenges, contains('daily_tracker'));
    expect(next.challenges['daily_tracker_2026-10-27'], true);
    expect(next.challenges['daily_tracker_2026-10-28'], true);
  });
  test('streak crosses month boundary and preserves best streak', () {
    final expenses = [
      for (var day = 25; day <= 31; day++) e(day),
      Expense(
        id: 'nov',
        description: 'Food',
        amount: 1,
        category: 'Food & Dining',
        date: DateTime(2026, 11, 1),
      ),
    ];
    final first = evaluate(expenses, date: DateTime(2026, 11, 1));
    expect(first.currentStreak, 8);
    expect(first.badges, contains('streak_champion'));
    final later = evaluate(
      expenses,
      previous: first,
      date: DateTime(2026, 11, 4),
    );
    expect(later.currentStreak, 0);
    expect(later.bestStreak, 8);
    expect(later.badges, contains('streak_champion'));
  });
  test('evaluation stages changes without mutating existing claims', () {
    final quests = <String>{};
    final badges = <String>{};
    final claims = <String, dynamic>{};
    RewardEngine.evaluate(
      expenses: [e(27)],
      now: now,
      monthlyBudget: 10000,
      hasCategoryBudget: false,
      categoryCount: 8,
      xp: 0,
      coins: 0,
      bestStreak: 0,
      completedQuests: quests,
      earnedBadges: badges,
      challengeClaims: claims,
      questRewards: {'first_expense': (xp: 10, coins: 5)},
      challengeRules: {
        'daily_tracker': (goal: 1, daily: true, xp: 20, coins: 10),
      },
    );
    expect(quests, isEmpty);
    expect(badges, isEmpty);
    expect(claims, isEmpty);
  });
}
