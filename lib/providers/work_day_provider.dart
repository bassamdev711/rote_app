import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_day.dart';
import '../repositories/work_day_repository.dart';
import '../models/inventory_load.dart';
import '../repositories/inventory_load_repository.dart';
import 'package:intl/intl.dart';
import 'global_refresh_provider.dart';

final workDayRepositoryProvider = Provider((ref) => WorkDayRepository());
final inventoryLoadRepositoryProvider = Provider((ref) => InventoryLoadRepository());

final currentWorkDayProvider = AsyncNotifierProvider<WorkDayNotifier, WorkDay?>(() {
  return WorkDayNotifier();
});

class WorkDayNotifier extends AsyncNotifier<WorkDay?> {
  WorkDayRepository get _workDayRepo => ref.read(workDayRepositoryProvider);
  InventoryLoadRepository get _inventoryLoadRepo => ref.read(inventoryLoadRepositoryProvider);

  @override
  Future<WorkDay?> build() async {
    ref.watch(globalRefreshProvider);
    return _workDayRepo.getActiveWorkDay();
  }

  Future<void> startNewDay(List<InventoryLoad> initialLoads) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final days = await _workDayRepo.getAllClosedDays();
    final existingDay = days.where((d) => d.date == dateStr).firstOrNull;

    String dayId;
    
    if (existingDay != null) {
      await _workDayRepo.openWorkDay(existingDay.id!);
      dayId = existingDay.id!;
    } else {
      final newDay = WorkDay(
        date: dateStr,
        isClosed: false,
        createdAt: DateTime.now().toIso8601String(),
      );
      dayId = await _workDayRepo.insert(newDay);
    }
    
    for (var load in initialLoads) {
      final loadWithId = load.copyWith(workDayId: dayId);
      await _inventoryLoadRepo.insert(loadWithId);
    }
    
    ref.read(globalRefreshProvider.notifier).refresh();
  }

  Future<void> closeDay(String id) async {
    await _workDayRepo.closeWorkDay(id);
    ref.read(globalRefreshProvider.notifier).refresh();
  }
}
