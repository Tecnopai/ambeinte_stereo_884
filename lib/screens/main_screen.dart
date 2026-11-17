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
import '../utils/tv.dart';
import '../widgets/tv_idle_guard.dart';
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
    _screens = [
      RadioPlayerScreen(onOpenPodcasts: () => _onTabTapped(2)),
      // Nota: NewsScreen requiere el audioManager si se inicializa aquí.
      // Se asume que NewsScreen también obtiene su manager internamente,
      // o se ajustaría para recibirlo, pero mantenemos la estructura sin parámetro.
      const NewsScreen(),
      const PodcastsScreen(),
      const AboutScreen(),
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
    for (final n in _tvMenuNodes) {
      n.dispose();
    }
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
    if (Tv.isTv) return _buildTvLayout();
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

  // ========== TELEVISOR ==========

  /// Interfaz para televisor: menú lateral grande manejado con el control
  /// remoto (flechas y OK) y el contenido a la derecha. La flecha izquierda
  /// lleva al menú y la derecha vuelve al contenido.
  Widget _buildTvLayout() {
    return TvIdleGuard(child: _buildTvScaffold());
  }

  Widget _buildTvScaffold() {
    return Scaffold(
      body: Row(
        children: [
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onTvMenuKey,
            child: FocusTraversalGroup(child: _buildTvMenu()),
          ),
          Expanded(
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _onTvContentKey,
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                // Las páginas cambian solo desde el menú.
                physics: const NeverScrollableScrollPhysics(),
                children: _screens,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const PodcastMiniPlayer(
        margin: EdgeInsets.fromLTRB(16, 8, 16, 12),
      ),
    );
  }

  /// Un nodo de foco por opción del menú de TV.
  late final List<FocusNode> _tvMenuNodes = List.generate(
    4,
    (i) => FocusNode(debugLabel: 'menu TV $i'),
  );

  /// Al salir del contenido hacia la izquierda, el foco va a la sección
  /// actual del menú (no a la opción que quede más cerca en la pantalla).
  KeyEventResult _onTvContentKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final current = FocusManager.instance.primaryFocus;
    if (current == null) return KeyEventResult.ignored;
    current.focusInDirection(TraversalDirection.left);
    final now = FocusManager.instance.primaryFocus;
    if (now == current || _tvMenuNodes.contains(now)) {
      _tvMenuNodes[_currentIndex].requestFocus();
    }
    return KeyEventResult.handled;
  }

  /// En el menú, arriba en la primera opción y abajo en la última no hacen
  /// nada (antes el foco saltaba al contenido).
  KeyEventResult _onTvMenuKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final current = FocusManager.instance.primaryFocus;
    final atTop =
        event.logicalKey == LogicalKeyboardKey.arrowUp &&
        current == _tvMenuNodes.first;
    final atBottom =
        event.logicalKey == LogicalKeyboardKey.arrowDown &&
        current == _tvMenuNodes.last;
    return atTop || atBottom ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  Widget _buildTvMenu() {
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 44,
                  height: 44,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ambiente\nStereo 88.4',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          for (var i = 0; i < _navigationItems.length; i++) ...[
            _buildTvMenuItem(i),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTvMenuItem(int index) {
    final item = _navigationItems[index];
    final selected = _currentIndex == index;
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return TvFocusable(
      focusNode: _tvMenuNodes[index],
      onPressed: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(14),
      focusScale: 1.04,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            _withBadge(
              item,
              Icon(
                selected ? item.selectedIcon : item.icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              item.label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : color,
                fontSize: 17,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
