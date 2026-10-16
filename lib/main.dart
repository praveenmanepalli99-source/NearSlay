import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/nearfix_state.dart';
import 'theme/app_theme.dart';
import 'screens/phone_auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/provider_dashboard_screen.dart';
import 'config/firebase_config.dart';
import 'services/sms_service.dart';
import 'package:flutter/services.dart';
import 'widgets/device_preview_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await FirebaseConfig.init();
  await SmsService.init();
  runApp(const NearFixApp());
}

class NearFixApp extends StatelessWidget {
  const NearFixApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NearFixState>(
      create: (_) => NearFixState(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'NearSlay - Colony Repair Services',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const DevicePreviewShell(
          child: RootScreen(),
        ),
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<NearFixState>(context);

    // If logged out or new user, ask for Mobile Number first
    if (!state.isLoggedIn || state.activeRole == AppRole.unregistered) {
      return const PhoneAuthScreen();
    }

    if (state.activeRole == AppRole.provider) {
      return const ProviderDashboardScreen();
    }

    return const HomeScreen();
  }
}
