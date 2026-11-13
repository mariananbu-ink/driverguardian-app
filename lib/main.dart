// DriverGuardian — School Bus Management (mobile).
// Parents track the bus & pay fees by UPI, drivers share GPS and mark
// attendance, school admins approve sign-ups and verify payments.
// Developed & Powered by Marian Anbu Juwan
import 'package:flutter/material.dart';

import 'api.dart';
import 'push.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'screens/splash.dart';
import 'ui.dart';

final navKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.I.load();
  await Push.init();
  Api.I.onUnauthorized = () {
    navKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  };
  Push.onForeground = (title, body) {
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text('$title\n$body'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
  };
  runApp(const DriverGuardianApp());
}

class DriverGuardianApp extends StatelessWidget {
  const DriverGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriverGuardian',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: navKey,
      scaffoldMessengerKey: messengerKey,
      home: SplashScreen(next: Api.I.token != null && Api.I.user != null ? const HomeScreen() : const LoginScreen()),
    );
  }
}
