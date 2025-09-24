import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import 'radio_player_screen.dart';
import 'news_screen.dart';
import 'about_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final AudioPlayerManager _audioManager = AudioPlayerManager();

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _audioManager.init();
    _screens = [
      RadioPlayerScreen(audioManager: _audioManager),
      NewsScreen(audioManager: _audioManager),
      AboutScreen(audioManager: _audioManager),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Note: No disposing _audioManager here as it's a singleton that should persist
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radio), label: 'Radio'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Noticias'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Acerca'),
        ],
      ),
    );
  }
}
