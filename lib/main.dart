import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';

import 'src/providers/auth_provider.dart';
import 'src/providers/connectivity_provider.dart';
import 'src/providers/data_provider.dart';
import 'src/providers/theme_provider.dart';
import 'src/services/db_service.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await DBService.initialize();
  }
  await NotificationService.initialize();

  final authProvider = AuthProvider();
  await authProvider.loadFromCache();

  final dataProvider = DataProvider();
  // Forward auth token to API service for authenticated requests
  if (authProvider.user != null) {
    dataProvider.setToken(authProvider.user!.token);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider<DataProvider>.value(value: dataProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const App(),
    ),
  );
}
