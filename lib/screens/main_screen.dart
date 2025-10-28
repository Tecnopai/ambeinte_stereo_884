import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'radio_player_screen.dart';
import 'news_screen.dart';
import 'about_screen.dart';
import '../utils/responsive_helper.dart';

/// Define el tipo de navegación utilizado, aunque no se usa directamente en esta clase.
enum NavigationType { bottom, rail }

/// Pantalla principal y contenedora de la aplicación.
///
/// Gestiona la navegación adaptativa entre las diferentes secciones (Radio, Noticias, Nosotros)
/// utilizando un BottomNavigationBar para móvil/portrait y un NavigationRail para tablet/desktop/automotive.
class MainScreen extends StatefulWidget {
  /// Constructor de MainScreen. El AudioManager se gestiona internamente por cada pantalla.
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// Estado y lógica de la pantalla principal.
class _MainScreenState extends State<MainScreen> {
  /// Índice de la pestaña actualmente seleccionada.
  int _currentIndex = 0;

  /// Controlador para gestionar la transición entre las páginas de contenido.
  final PageController _pageController = PageController();

  /// Lista de los widgets de las pantallas de contenido (Radio, Noticias, Nosotros).
  late List<Widget> _screens;

  /// Lista de elementos de navegación con íconos y etiquetas.
  late List<NavigationItem> _navigationItems;

  /// Instancia de Firebase Analytics para el seguimiento.
  final analytics = FirebaseAnalytics.instance;

  /// {inheritdoc}
  @override
  void initState() {
    super.initState();
    // Analítica: Registra la vista de la pantalla principal.
    analytics.logScreenView(screenName: 'main', screenClass: 'MainScreen');

    // Inicialización de las pantallas (cada una obtiene el singleton AudioManager)
    _screens = const [
      RadioPlayerScreen(),
      // Nota: NewsScreen requiere el audioManager si se inicializa aquí.
      // Se asume que NewsScreen también obtiene su manager internamente,
      // o se ajustaría para recibirlo, pero mantenemos la estructura sin parámetro.
      NewsScreen(),
      AboutScreen(),
    ];

    // Definición de los elementos de navegación
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

  /// {inheritdoc}
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Maneja el cambio de página cuando el usuario se desplaza (swipe) en el PageView.
  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  /// Maneja la selección de un elemento de navegación (tap en BottomBar o Rail).
  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);

    // Animación suave al cambiar de página
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// {inheritdoc}
  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    // Determina si se debe usar NavigationRail o BottomNavigationBar
    final useNavigationRail = responsive.useNavigationRail;

    return Scaffold(
      body: Row(
        children: [
          // Muestra el NavigationRail en formatos de pantalla anchos (tablet, desktop, automotive)
          if (useNavigationRail) _buildNavigationRail(responsive),

          // Contenido principal (Page View)
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              // Deshabilita el desplazamiento horizontal en entornos automotrices
              // para evitar cambios accidentales de pantalla al conductor.
              physics: responsive.isAutomotive
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              children: _screens,
            ),
          ),
        ],
      ),

      // Muestra el BottomNavigationBar solo en dispositivos móviles y tablets en vertical
      bottomNavigationBar: useNavigationRail
          ? null
          : _buildBottomNavigationBar(responsive),
    );
  }

  /// Construye el widget NavigationRail, adaptando su tamaño y estilo al dispositivo.
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

    // Se extiende (muestra etiquetas) en automotive, tablets grandes y desktop
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
        // Sombra sutil para el diseño Automotive
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
        // En `extended: false`, se fuerza a no mostrar la etiqueta.
        labelType: isExtended ? null : NavigationRailLabelType.none,
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
            // El Tooltip es útil para NavigationRail cuando no está extendido
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

  /// Construye el widget BottomNavigationBar, adaptando su tamaño y estilo al dispositivo móvil.
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
          // El tooltip se mueve al widget Icon/Padding para mejor accesibilidad y visualización
          tooltip: '',
        );
      }).toList(),
    );
  }
}

/// Modelo de datos simple para almacenar la información de cada elemento de navegación.
class NavigationItem {
  /// Icono por defecto.
  final IconData icon;

  /// Icono cuando el elemento está seleccionado.
  final IconData selectedIcon;

  /// Etiqueta de texto a mostrar.
  final String label;

  /// Texto de tooltip para accesibilidad.
  final String tooltip;

  /// Constructor de NavigationItem.
  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
  });
}
