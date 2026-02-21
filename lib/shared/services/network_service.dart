import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// خدمة كشف حالة الاتصال بالإنترنت
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final _connectivity = Connectivity();
  final _connectionController = StreamController<bool>.broadcast();
  bool _isConnected = true;

  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  void init() {
    _checkConnection();
    _connectivity.onConnectivityChanged.listen((results) {
      _updateConnection(results);
    });
  }

  Future<void> _checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnection(results);
  }

  void _updateConnection(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    // إذا كان هناك أي اتصال (WiFi, mobile, ethernet) نعتبره متصلاً
    _isConnected = results.any((r) => r != ConnectivityResult.none);
    
    if (wasConnected != _isConnected) {
      _connectionController.add(_isConnected);
      if (kDebugMode) {
        debugPrint('🌐 Network status: ${_isConnected ? "Connected" : "Disconnected"}');
      }
    }
  }

  void dispose() {
    _connectionController.close();
  }
}
