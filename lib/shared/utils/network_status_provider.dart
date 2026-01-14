import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus {
  online,
  offline,
}

final networkStatusProvider =
    StreamProvider<NetworkStatus>((ref) async* {
  final connectivity = Connectivity();

  // الحالة الابتدائية
  final initialRaw = await connectivity.checkConnectivity();
  final initial = _normalizeResult(initialRaw);
  yield _mapConnectivity(initial);

  // الاستماع للتغييرات
  yield* connectivity.onConnectivityChanged.map((raw) {
    final result = _normalizeResult(raw);
    return _mapConnectivity(result);
  });
});

ConnectivityResult _normalizeResult(dynamic raw) {
  if (raw is ConnectivityResult) {
    return raw;
  }
  if (raw is List<ConnectivityResult>) {
    if (raw.isEmpty) return ConnectivityResult.none;
    return raw.last;
  }
  // fallback حذر في حال تغيّر الـ API
  return ConnectivityResult.none;
}

NetworkStatus _mapConnectivity(ConnectivityResult result) {
  if (result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet) {
    return NetworkStatus.online;
  }
  return NetworkStatus.offline;
}
