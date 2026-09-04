import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'views/dashboard/dashboard_screen.dart';

void main() {
  debugPrint('🚀 ORCA MAIN FUNCTION STARTED 🚀');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 WIDGETS BINDING INITIALIZED 🚀');

  // Lock status bar and navigation bar styling for tactical dark mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF050B14),
      systemNavigationBarIconBrightness: Brightness.light,
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
      theme: AppTheme.darkTactical,
      home: const DashboardScreen(),
    );
  }
}
