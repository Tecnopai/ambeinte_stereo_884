import 'package:flutter/material.dart';
import '../services/audio_player_manager.dart';
import 'radio_player_screen.dart';
import 'news_screen.dart';
import 'about_screen.dart';

/// Pantalla principal de la aplicación con navegación por pestañas
/// Contiene tres secciones: Radio, Noticias y Nosotros
/// Adapta su navegación según el tipo de dispositivo (móvil/tablet) y orientación
class MainScreen extends StatefulWidget {
  // Gestor del reproductor de audio compartido entre todas las pantallas
  final AudioPlayerManager audioManager;

  const MainScreen({super.key, required this.audioManager});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Índice de la pestaña actual seleccionada
  int _currentIndex = 0;

  // Controlador para manejar el PageView y sus animaciones
  final PageController _pageController = PageController();

  // Lista de pantallas que se mostrarán en cada pestaña
  late List<Widget> _screens;

  // Configuración de los elementos de navegación (iconos, etiquetas, tooltips)
  List<NavigationItem> _navigationItems = [];

  @override
  void initState() {
    super.initState();

    // Inicializar las pantallas usando el audioManager compartido
    // Todas las pantallas reciben la misma instancia para mantener el estado
    _screens = [
      RadioPlayerScreen(audioManager: widget.audioManager),
      NewsScreen(audioManager: widget.audioManager),
      AboutScreen(audioManager: widget.audioManager),
    ];

    // Configurar los elementos de navegación con sus iconos y etiquetas
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
    // Nota: No se descarta audioManager aquí porque es un singleton
    // que debe persistir durante toda la vida de la aplicación
    super.dispose();
  }

  /// Callback cuando el usuario hace swipe entre páginas
  /// Actualiza el índice actual para sincronizar la navegación
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Callback cuando el usuario toca una pestaña en la navegación
  /// Anima la transición hacia la página seleccionada
  void _onTabTapped(int index) {
    // Evitar animaciones innecesarias si ya estamos en la misma pestaña
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    // Animar el cambio de página con una transición suave
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtener información del dispositivo para diseño adaptativo
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final isLandscape = screenSize.width > screenSize.height;

    // En tablets en modo horizontal, usar NavigationRail lateral
    // En otros casos, usar BottomNavigationBar tradicional
    final useNavigationRail = isTablet && isLandscape;

    return Scaffold(
      body: Row(
        children: [
          // ===== NAVIGATION RAIL (tablets en landscape) =====
          // Barra de navegación lateral para aprovechar el espacio horizontal
          if (useNavigationRail) _buildNavigationRail(),

          // ===== CONTENIDO PRINCIPAL =====
          // PageView permite hacer swipe entre pantallas
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _screens,
            ),
          ),
        ],
      ),

      // ===== BOTTOM NAVIGATION BAR (móviles y tablets portrait) =====
      // Barra de navegación inferior tradicional
      bottomNavigationBar: useNavigationRail
          ? null
          : _buildBottomNavigationBar(isTablet),
    );
  }

  /// Construye la barra de navegación lateral para tablets en horizontal
  /// Muestra iconos y etiquetas extendidas en el lado izquierdo
  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onTabTapped,
      extended: true, // Mostrar etiquetas junto a los iconos
      minExtendedWidth: 200,
      labelType:
          NavigationRailLabelType.none, // Etiquetas controladas por 'extended'
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      destinations: _navigationItems
          .map(
            (item) => NavigationRailDestination(
              // Icono sin seleccionar con tooltip
              icon: Tooltip(message: item.tooltip, child: Icon(item.icon)),
              // Icono seleccionado con tooltip
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

  /// Construye la barra de navegación inferior tradicional
  /// Adapta tamaños según el tipo de dispositivo
  ///
  /// [isTablet] - Indica si el dispositivo es una tablet para ajustar tamaños
  Widget _buildBottomNavigationBar(bool isTablet) {
    // Tamaños adaptativos según el dispositivo
    final iconSize = isTablet ? 28.0 : 24.0;
    final fontSize = isTablet ? 14.0 : 12.0;

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      type:
          BottomNavigationBarType.fixed, // Todas las pestañas siempre visibles
      enableFeedback: true, // Retroalimentación háptica al tocar
      elevation: isTablet ? 12 : 8,
      iconSize: iconSize,
      selectedFontSize: fontSize,
      unselectedFontSize: fontSize * 0.85,
      items: _navigationItems
          .map(
            (item) => BottomNavigationBarItem(
              // Icono sin seleccionar
              icon: Tooltip(
                message: item.tooltip,
                child: Icon(item.icon, size: iconSize),
              ),
              // Icono seleccionado
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

/// Clase modelo para organizar los datos de cada elemento de navegación
/// Contiene la información necesaria para mostrar iconos, etiquetas y tooltips
class NavigationItem {
  // Icono cuando la pestaña no está seleccionada
  final IconData icon;

  // Icono cuando la pestaña está seleccionada
  final IconData selectedIcon;

  // Texto de la etiqueta
  final String label;

  // Texto del tooltip al mantener presionado
  final String tooltip;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
  });
}
