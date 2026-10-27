import '../models/expense.dart';
import 'money.dart';

typedef Reward = ({int xp, int coins});

class RewardEvaluation {
  final int xp, coins, currentStreak, bestStreak;
  final Set<String> quests, badges;
  final Map<String, dynamic> challenges;
  final List<String> newQuests, newChallenges;
  const RewardEvaluation({
    required this.xp,
    required this.coins,
    required this.currentStreak,
    required this.bestStreak,
    required this.quests,
    required this.badges,
    required this.challenges,
    required this.newQuests,
    required this.newChallenges,
  });
}

/// Pure reward rules: evaluation never mutates the supplied progress.
class RewardEngine {
  static Map<String, int> challengeProgress(
    List<Expense> expenses,
    DateTime now,
  ) {
    final today = calendarDate(now);
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final daily = expenses.where((e) => calendarDate(e.date) == today).toList();
    final weekly = expenses
        .where(
          (e) =>
              !calendarDate(e.date).isBefore(monday) &&
              !calendarDate(e.date).isAfter(today),
        )
        .toList();
    return {
      'daily_tracker': daily.isEmpty ? 0 : 1,
      'daily_variety': daily.map((e) => e.category).toSet().length,
      'weekly_consistency': weekly.map((e) => dayKey(e.date)).toSet().length,
      'weekly_explorer': weekly.map((e) => e.category).toSet().length,
    };
  }

  static int streak(List<Expense> expenses, DateTime now) {
    final days = expenses.map((e) => dayKey(e.date)).toSet();
    var cursor = calendarDate(now);
    if (!days.contains(dayKey(cursor))) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (days.contains(dayKey(cursor))) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  static RewardEvaluation evaluate({
    required List<Expense> expenses,
    required DateTime now,
    required double monthlyBudget,
    required bool hasCategoryBudget,
    required int categoryCount,
    required int xp,
    required int coins,
    required int bestStreak,
    required Set<String> completedQuests,
    required Set<String> earnedBadges,
    required Map<String, dynamic> challengeClaims,
    required Map<String, Reward> questRewards,
    required Map<String, ({int goal, bool daily, int xp, int coins})>
    challengeRules,
  }) {
    final actual = expenses
        .where((e) => !calendarDate(e.date).isAfter(calendarDate(now)))
        .toList();
    final month = actual
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final spend = month.fold<int>(0, (sum, e) => sum + e.amountCentavos);
    final budget = Money.centavos(monthlyBudget);
    final count = actual.length;
    final used = actual.map((e) => e.category).toSet().length;
    final current = streak(actual, now);
    final eligible = <String>{
      if (count >= 1) 'first_expense',
      if (count >= 5) 'track_five_expenses',
      if (count >= 10) 'track_ten_expenses',
      if (count >= 25) 'track_twenty_five',
      if (used >= 3) 'three_categories',
      if (used >= categoryCount) 'all_categories',
      if (budget > 0) 'set_monthly_budget',
      if (hasCategoryBudget) 'set_category_budget',
      if (month.length >= 5 && budget > 0 && spend <= budget)
        'under_budget_month',
      if (month.length >= 3 && budget > 0 && spend * 2 <= budget) 'big_saver',
      if (current >= 3) 'streak_3',
      if (current >= 7) 'streak_7',
      if (current >= 14) 'streak_14',
      if (current >= 30) 'streak_30',
    };
    final quests = {...completedQuests};
    final newQuests = <String>[];
    for (final id in eligible) {
      final reward = questRewards[id];
      if (reward != null && quests.add(id)) {
        xp += reward.xp;
        coins += reward.coins;
        newQuests.add(id);
      }
    }
    final badges = {
      ...earnedBadges,
      if (count >= 1) 'first_steps',
      if (used >= categoryCount) 'category_explorer',
      if (quests.contains('under_budget_month')) 'budget_guardian',
      if (current >= 7) 'streak_champion',
      if (count >= 25) 'dedicated_tracker',
      if (quests.contains('big_saver')) 'big_saver',
    };
    final claims = {...challengeClaims};
    final progress = challengeProgress(actual, now);
    final newChallenges = <String>[];
    for (final entry in challengeRules.entries) {
      final rule = entry.value;
      final key = '${entry.key}_${rule.daily ? dayKey(now) : weekKey(now)}';
      if ((progress[entry.key] ?? 0) >= rule.goal && claims[key] != true) {
        claims[key] = true;
        xp += rule.xp;
        coins += rule.coins;
        newChallenges.add(entry.key);
      }
    }
    return RewardEvaluation(
      xp: xp,
      coins: coins,
      currentStreak: current,
      bestStreak: current > bestStreak ? current : bestStreak,
      quests: quests,
      badges: badges,
      challenges: claims,
      newQuests: newQuests,
      newChallenges: newChallenges,
    );
  }
}
