import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'activity_store.dart';

export 'activity_store.dart';

final activityStoreProvider = Provider<ActivityStore>((_) => ActivityStore());

final activityProvider =
    AsyncNotifierProvider<ActivityNotifier, List<ActivityEvent>>(
  ActivityNotifier.new,
);

class ActivityNotifier extends AsyncNotifier<List<ActivityEvent>> {
  @override
  Future<List<ActivityEvent>> build() async =>
      ref.read(activityStoreProvider).loadAll();

  Future<void> log(ActivityEvent event) async {
    await ref.read(activityStoreProvider).add(event);
    state = AsyncData(<ActivityEvent>[event, ...state.value ?? <ActivityEvent>[]].take(50).toList());
  }

  Future<void> clear() async {
    await ref.read(activityStoreProvider).clear();
    state = const AsyncData([]);
  }
}
