import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'views/dashboard/dashboard_screen.dart';

void main() {
  debugPrint('🚀 ORCA MAIN FUNCTION STARTED 🚀');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 WIDGETS BINDING INITIALIZED 🚀');

  // Lock status bar and navigation bar styling for clean light mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const OrcaApp());
}

class OrcaApp extends StatelessWidget {
  const OrcaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.sunlightDeck,
      themeMode: ThemeMode.light,
      home: const DashboardScreen(),
    );
  }
}
