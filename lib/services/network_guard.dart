import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

const _onlineCheckTimeout = Duration(seconds: 2);
const networkOpTimeout = Duration(seconds: 12);

/// 检查是否有网。connectivity_plus 在 Windows 上偶尔会一直不返回，
/// 超时后当作有网，真正的请求再带超时，避免启动界面卡死。
Future<bool> hasNetwork() async {
  try {
    final result = await Connectivity()
        .checkConnectivity()
        .timeout(_onlineCheckTimeout);
    return result.any((e) => e != ConnectivityResult.none);
  } on TimeoutException {
    return true;
  } catch (_) {
    return true;
  }
}

Future<T> withNetworkTimeout<T>(Future<T> future) {
  return future.timeout(networkOpTimeout);
}
