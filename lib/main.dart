import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'core/firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'state/shop_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authService = AuthService(FirebaseAuth.instance);
  final api = ApiClient(authService);
  final controller = ShopController(api);
  runApp(SmarkMartApp(controller: controller));
  controller.bootstrap();
}

class SmarkMartApp extends StatelessWidget {
  const SmarkMartApp({super.key, required this.controller});
  final ShopController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConfig.appName,
        theme: AppTheme.light,
        home: const HomeScreen(),
      ),
    );
  }
}
