import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import 'radio_player_screen.dart';
import 'news_screen.dart';
import 'about_screen.dart';
import '../utils/responsive_helper.dart';

enum NavigationType { bottom, rail }

/// Pantalla principal mejorada con navegación adaptativa
class MainScreen extends StatefulWidget {
  final AudioPlayerManager audioManager;

  const MainScreen({super.key, required this.audioManager});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  late List<Widget> _screens;
  late List<NavigationItem> _navigationItems;

  @override
  void initState() {
    super.initState();

    // Inicializar las pantallas usando el audioManager compartido
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
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final useNavigationRail = responsive.useNavigationRail;

    return Scaffold(
      body: Row(
        children: [
          // NavigationRail para tablets en landscape y automotive
          if (useNavigationRail) _buildNavigationRail(responsive),

          // Contenido principal
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              // Deshabilitar swipe en automotive para evitar distracciones
              physics: responsive.isAutomotive
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              children: _screens,
            ),
          ),
        ],
      ),

      // BottomNavigationBar para móviles y tablets portrait
      bottomNavigationBar: useNavigationRail
          ? null
          : _buildBottomNavigationBar(responsive),
    );
  }

  /// NavigationRail adaptativo según dispositivo
  Widget _buildNavigationRail(ResponsiveHelper responsive) {
    final railWidth = responsive.getValue(
      phone: 72.0,
      tablet: 200.0,
      desktop: 240.0,
      automotive: 180.0,
    );

    final iconSize = responsive.getValue(
      phone: 24.0,
      largePhone: 26.0,
      tablet: 28.0,
      desktop: 32.0,
      automotive: 32.0,
    );

    final labelTextSize = responsive.getValue(
      phone: 12.0,
      largePhone: 13.0,
      tablet: 14.0,
      desktop: 16.0,
      automotive: 16.0,
    );

    // En automotive, siempre extendido con labels
    // En tablets, extendido solo en landscape grande
    final isExtended =
        responsive.isAutomotive ||
        responsive.isLargeTablet ||
        responsive.isDesktop;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        // Sombra sutil en automotive
        boxShadow: responsive.isAutomotive
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ]
            : null,
      ),
      child: NavigationRail(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        extended: isExtended,
        minExtendedWidth: railWidth,
        minWidth: responsive.getValue(
          phone: 72.0,
          tablet: 80.0,
          automotive: 90.0,
        ),
        labelType: NavigationRailLabelType.none,
        backgroundColor: Colors.transparent,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(
          size: iconSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        unselectedIconTheme: IconThemeData(
          size: iconSize * 0.9,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: TextStyle(
          fontSize: labelTextSize,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: labelTextSize * 0.9,
          fontWeight: FontWeight.normal,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        destinations: _navigationItems.map((item) {
          return NavigationRailDestination(
            icon: Tooltip(message: item.tooltip, child: Icon(item.icon)),
            selectedIcon: Tooltip(
              message: item.tooltip,
              child: Icon(item.selectedIcon),
            ),
            label: Text(item.label),
            padding: EdgeInsets.symmetric(
              vertical: responsive.getValue(
                phone: 8.0,
                tablet: 12.0,
                automotive: 16.0,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// BottomNavigationBar adaptativo
  Widget _buildBottomNavigationBar(ResponsiveHelper responsive) {
    final iconSize = responsive.getValue(
      smallPhone: 22.0,
      phone: 24.0,
      largePhone: 26.0,
      tablet: 28.0,
    );

    final fontSize = responsive.getValue(
      smallPhone: 11.0,
      phone: 12.0,
      largePhone: 13.0,
      tablet: 14.0,
    );

    final elevation = responsive.getValue(phone: 8.0, tablet: 12.0);

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      type: BottomNavigationBarType.fixed,
      enableFeedback: true,
      elevation: elevation,
      iconSize: iconSize,
      selectedFontSize: fontSize,
      unselectedFontSize: fontSize * 0.85,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      selectedIconTheme: IconThemeData(size: iconSize),
      unselectedIconTheme: IconThemeData(size: iconSize * 0.9),
      selectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: fontSize * 0.85,
      ),
      items: _navigationItems.map((item) {
        return BottomNavigationBarItem(
          icon: Tooltip(
            message: item.tooltip,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: responsive.getValue(
                  phone: 4.0,
                  largePhone: 6.0,
                  tablet: 8.0,
                ),
              ),
              child: Icon(item.icon),
            ),
          ),
          activeIcon: Tooltip(
            message: item.tooltip,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: responsive.getValue(
                  phone: 4.0,
                  largePhone: 6.0,
                  tablet: 8.0,
                ),
              ),
              child: Icon(item.selectedIcon),
            ),
          ),
          label: item.label,
          tooltip: '',
        );
      }).toList(),
    );
  }
}

/// Modelo de datos para elementos de navegación
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
