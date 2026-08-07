import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A simple global provider that acts as an event bus.
class GlobalRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() {
    state++;
  }
}

final globalRefreshProvider = NotifierProvider<GlobalRefreshNotifier, int>(GlobalRefreshNotifier.new);
