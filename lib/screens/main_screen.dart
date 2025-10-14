import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import 'radio_player_screen.dart';
import 'news_screen.dart';
import 'about_screen.dart';

class MainScreen extends StatefulWidget {
  // ✅ Ahora recibe el audioManager desde SplashScreen
  final AudioPlayerManager audioManager;

  const MainScreen({
    super.key,
    required this.audioManager, // ✅ Parámetro requerido
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // ❌ ELIMINADO: No crear nueva instancia aquí
  // final AudioPlayerManager _audioManager = AudioPlayerManager();

  late List<Widget> _screens;
  List<NavigationItem> _navigationItems = [];

  @override
  void initState() {
    super.initState();

    // ❌ ELIMINADO: Ya no inicializar aquí, viene inicializado desde main.dart
    // _audioManager.init();

    // ✅ ACTUALIZADO: Usar widget.audioManager que viene desde SplashScreen
    _screens = [
      RadioPlayerScreen(audioManager: widget.audioManager),
      NewsScreen(audioManager: widget.audioManager),
      AboutScreen(audioManager: widget.audioManager),
    ];

    _navigationItems = [
      NavigationItem(
        icon: Icons.radio,
        selectedIcon: Icons.radio,
        label: 'Radio',
        tooltip: 'Reproductor de radio',
      ),
      NavigationItem(
        icon: Icons.article_outlined,
        selectedIcon: Icons.article,
        label: 'Noticias',
        tooltip: 'Últimas noticias',
      ),
      NavigationItem(
        icon: Icons.info_outline,
        selectedIcon: Icons.info,
        label: 'Nosotros',
        tooltip: 'Información de la app',
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Nota: No se debe descartar audioManager aquí ya que es un singleton que debe persistir
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return; // Evitar animaciones innecesarias

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
    // Obtener información del dispositivo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final isLandscape = screenSize.width > screenSize.height;

    // En tablets landscape, usar NavigationRail en lugar de BottomNavigationBar
    final useNavigationRail = isTablet && isLandscape;

    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail para tablets en landscape
          if (useNavigationRail) _buildNavigationRail(),

          // Contenido principal
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _screens,
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar para teléfonos y tablets en portrait
      bottomNavigationBar: useNavigationRail
          ? null
          : _buildBottomNavigationBar(isTablet),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onTabTapped,
      extended: true, // Mostrar etiquetas
      minExtendedWidth: 200,
      labelType: NavigationRailLabelType
          .none, // Las etiquetas se muestran por 'extended'
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      destinations: _navigationItems
          .map(
            (item) => NavigationRailDestination(
              icon: Tooltip(message: item.tooltip, child: Icon(item.icon)),
              selectedIcon: Tooltip(
                message: item.tooltip,
                child: Icon(item.selectedIcon),
              ),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomNavigationBar(bool isTablet) {
    final iconSize = isTablet ? 28.0 : 24.0;
    final fontSize = isTablet ? 14.0 : 12.0;

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      type: BottomNavigationBarType
          .fixed, // Asegura que todas las tabs sean visibles
      enableFeedback: true, // Haptic feedback
      elevation: isTablet ? 12 : 8,
      iconSize: iconSize,
      selectedFontSize: fontSize,
      unselectedFontSize: fontSize * 0.85,
      items: _navigationItems
          .map(
            (item) => BottomNavigationBarItem(
              icon: Tooltip(
                message: item.tooltip,
                child: Icon(item.icon, size: iconSize),
              ),
              activeIcon: Tooltip(
                message: item.tooltip,
                child: Icon(item.selectedIcon, size: iconSize),
              ),
              label: item.label,
              tooltip: '', // Vacío porque usamos Tooltip personalizado
            ),
          )
          .toList(),
    );
  }
}

// Clase para organizar los elementos de navegación
class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
  });
}
