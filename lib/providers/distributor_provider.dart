import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDistributorNameKey = 'distributor_name';

final distributorNameProvider = AsyncNotifierProvider<DistributorNameNotifier, String>(
  DistributorNameNotifier.new,
);

class DistributorNameNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDistributorNameKey) ?? '';
  }

  Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDistributorNameKey, name);
    state = AsyncData(name);
  }
}
