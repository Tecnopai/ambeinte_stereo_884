import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import '../screens/main_screen.dart';

class AmbientStereoApp extends StatelessWidget {
  const AmbientStereoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambient Stereo FM',
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
