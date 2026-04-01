import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity;

  ConnectivityProvider({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity() {
    _initialize();
  }

  ConnectivityResult _status = ConnectivityResult.none;
  ConnectivityResult get status => _status;

  bool get isOnline => _status != ConnectivityResult.none;

  void _initialize() {
    try {
      _connectivity.onConnectivityChanged.listen((result) {
        _status = result;
        notifyListeners();
      }, onError: (e) {
        debugPrint('Connectivity stream error: $e');
      });

      _connectivity.checkConnectivity().then((result) {
        _status = result;
        notifyListeners();
      }).catchError((e) {
        debugPrint('Connectivity check error: $e');
      });
    } catch (e) {
      debugPrint('Connectivity init error: $e');
    }
  }
}
