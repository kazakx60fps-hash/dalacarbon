// DalaCarbon AI — мобильді қосымша.
// Ағын: заставка (спутник алқаптардың үстінен ұшады) → кіру → жүктелу → басты бет.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const DalaCarbonApp());
}

class DalaCarbonApp extends StatelessWidget {
  const DalaCarbonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DalaCarbon AI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}
