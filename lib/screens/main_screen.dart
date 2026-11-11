import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'radio_player_screen.dart';
import 'news_screen.dart';
import 'podcasts_screen.dart';
import 'about_screen.dart';
import 'report_problem_screen.dart';
import '../utils/responsive_helper.dart';
import '../utils/version_checker.dart';
import '../core/theme/app_colors.dart';
import '../widgets/podcast_widgets.dart';
import '../services/podcast_service.dart';

/// Define el tipo de navegación utilizado, aunque no se usa directamente en esta clase.
enum NavigationType { bottom, rail }

/// Pantalla principal y contenedora de la aplicación.
///
/// Gestiona la navegación adaptativa entre las diferentes secciones (Radio, Noticias, Podcast, Nosotros)
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

  /// {inheritdoc}
  @override
  void initState() {
    super.initState();

    // Inicialización de las pantallas (cada una obtiene el singleton AudioManager)
    _screens = const [
      RadioPlayerScreen(),
      // Nota: NewsScreen requiere el audioManager si se inicializa aquí.
      // Se asume que NewsScreen también obtiene su manager internamente,
      // o se ajustaría para recibirlo, pero mantenemos la estructura sin parámetro.
      NewsScreen(),
      PodcastsScreen(),
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
        icon: Icons.podcasts_outlined,
        selectedIcon: Icons.podcasts,
        label: 'Podcast',
        tooltip: 'Podcasts',
        badge: PodcastService.instance.hasNew,
      ),
      NavigationItem(
        icon: Icons.info_outline,
        selectedIcon: Icons.info,
        label: 'Nosotros',
        tooltip: 'Información de la app',
      ),
    ];

    // Revisar si hay episodios nuevos (punto verde en "Podcast"). Se espera a
    // que la radio arranque para no competir por la conexión.
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) PodcastService.instance.checkForNew();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await VersionChecker.checkVersion(context);

      // Si la última vez la radio falló, ofrecer enviar un reporte. Se espera
      // un momento para no aparecer encima del arranque de la radio.
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      await ReportProblemScreen.offerIfPreviousSessionFailed(context);
    });
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
      // El mini reproductor del podcast va encima de la barra inferior
      // (o solo, en pantallas con barra lateral).
      bottomNavigationBar: useNavigationRail
          ? const SafeArea(
              top: false,
              child: PodcastMiniPlayer(
                margin: EdgeInsets.fromLTRB(12, 8, 12, 8),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PodcastMiniPlayer(
                  margin: EdgeInsets.fromLTRB(20, 8, 20, 0),
                ),
                _buildBottomNavigationBar(responsive),
              ],
            ),
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
            icon: Tooltip(
              message: item.tooltip,
              child: _withBadge(item, Icon(item.icon)),
            ),
            selectedIcon: Tooltip(
              message: item.tooltip,
              child: _withBadge(item, Icon(item.selectedIcon)),
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

  /// Barra de navegación flotante estilo iOS — píldora con blur.
  Widget _buildBottomNavigationBar(ResponsiveHelper responsive) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_navigationItems.length, (index) {
                  return _buildNavItem(
                    item: _navigationItems[index],
                    isSelected: _currentIndex == index,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _onTabTapped(index);
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Agrega el punto verde de "hay novedades" al ícono, si corresponde.
  Widget _withBadge(NavigationItem item, Widget icon, {Key? key}) {
    final badge = item.badge;
    if (badge == null) return KeyedSubtree(key: key, child: icon);
    return ValueListenableBuilder<bool>(
      key: key,
      valueListenable: badge,
      builder: (context, show, child) => Badge(
        isLabelVisible: show,
        smallSize: 9,
        backgroundColor: AppColors.accent,
        child: child,
      ),
      child: icon,
    );
  }

  Widget _buildNavItem({
    required NavigationItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _withBadge(
                item,
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 24,
                ),
                key: ValueKey(isSelected),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
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

  /// Muestra un punto en el ícono mientras sea true (opcional).
  final ValueListenable<bool>? badge;

  /// Constructor de NavigationItem.
  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
    this.badge,
  });
}
