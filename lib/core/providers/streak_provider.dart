import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/diary_repository.dart';
import 'app_providers.dart';

/// 연속 기록 스트릭을 계산하는 Provider
final streakProvider = FutureProvider.autoDispose<int>((ref) async {
  final child = ref.watch(currentChildProvider);
  if (child == null) return 0;

  final diaryRepo = ref.read(diaryRepositoryProvider);
  final entries = await diaryRepo.getDiaryEntries(child.id);

  if (entries.isEmpty) return 0;

  // Group entries by date (date only, no time)
  final datesWithEntries = <DateTime>{};
  for (final entry in entries) {
    final d = entry.recordedAt;
    datesWithEntries.add(DateTime(d.year, d.month, d.day));
  }

  // Count consecutive days backwards from today
  final today = DateTime.now();
  var currentDate = DateTime(today.year, today.month, today.day);
  int streak = 0;

  while (datesWithEntries.contains(currentDate)) {
    streak++;
    currentDate = currentDate.subtract(const Duration(days: 1));
  }

  return streak;
});
