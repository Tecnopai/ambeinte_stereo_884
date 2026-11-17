import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
// Importa el tema de la aplicación.
import 'theme/app_theme.dart';
// Importa la pantalla inicial de la aplicación.
import '../screens/splash_screen.dart';
import '../services/audio_player_manager.dart';
import '../utils/tv.dart';
import 'theme/app_colors.dart';

/// {@template ambient_stereo_app}
/// Widget raíz de la aplicación Ambiente Stereo 88.4 FM.
///
/// Este widget es un [StatefulWidget] que administra el estado del ciclo de vida
/// de la aplicación mediante [WidgetsBindingObserver] para fines de analítica.
/// {@endtemplate}
class AmbientStereoApp extends StatefulWidget {
  /// Constructor constante para [AmbientStereoApp].
  const AmbientStereoApp({super.key});

  @override
  State<AmbientStereoApp> createState() => _AmbientStereoAppState();
}

/// Estado asociado al widget [AmbientStereoApp].
///
/// Implementa [WidgetsBindingObserver] para escuchar los cambios en el estado
/// del ciclo de vida de la aplicación (ej. suspendida, reanudada, inactiva).
class _AmbientStereoAppState extends State<AmbientStereoApp>
    with WidgetsBindingObserver {
  /// Inicializa el estado del widget.
  @override
  void initState() {
    super.initState();

    // Registra esta clase como observador del ciclo de vida de la aplicación.
    WidgetsBinding.instance.addObserver(this);

    // Nota: El singleton se inicializa automáticamente cuando cualquier pantalla lo necesite
  }

  /// Limpia el observador cuando el widget se cierra o se elimina.
  @override
  void dispose() {
    // Es crucial remover el observador para evitar fugas de memoria.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Se ejecuta cada vez que el estado del ciclo de vida de la aplicación cambia.
  ///
  /// @param state El nuevo estado del ciclo de vida ([AppLifecycleState]).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AudioPlayerManager().onAppResumed();
      // En iOS, volume_controller vuelve a poner la sesión en `.mixWithOthers`
      // al regresar a primer plano; se restaura la sesión exclusiva.
      AudioPlayerManager().restoreExclusiveAudioSession();
    } else if (state == AppLifecycleState.paused) {
      AudioPlayerManager().onAppPaused();
    }
  }

  /// Tema para TV: lo seleccionado con el control remoto se ve claro, con un
  /// fondo verde y, en los botones, un borde verde claro.
  static ThemeData _tvTheme(ThemeData base) {
    ButtonStyle withRing(ButtonStyle? style) {
      return (style ?? const ButtonStyle()).copyWith(
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const BorderSide(color: AppColors.accent, width: 3)
              : null,
        ),
      );
    }

    return base.copyWith(
      focusColor: AppColors.primary.withValues(alpha: 0.45),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: withRing(base.elevatedButtonTheme.style),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: withRing(base.filledButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: withRing(base.textButtonTheme.style),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: withRing(base.iconButtonTheme.style),
      ),
    );
  }

  /// Construye la interfaz de usuario principal de la aplicación.
  @override
  Widget build(BuildContext context) {
    // En un televisor siempre se marca lo seleccionado (no hay toques que
    // escondan el resaltado, como en el teléfono).
    if (Tv.isTv) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    }

    return MaterialApp(
      title: 'Ambiente Stereo 88.4 FM',
      // El botón OK del control remoto "toca" lo seleccionado.
      shortcuts: {...WidgetsApp.defaultShortcuts, ...Tv.activateShortcuts},
      // Aplica el tema oscuro definido en app_theme.dart. En TV, el resaltado
      // de lo seleccionado es más visible.
      theme: Tv.isTv ? _tvTheme(AppTheme.darkTheme) : AppTheme.darkTheme,
      // Desactiva la etiqueta de "DEBUG" en la esquina superior derecha.
      debugShowCheckedModeBanner: false,
      // La pantalla de inicio de la aplicación es la SplashScreen.
      home: const SplashScreen(),

      builder: (context, widget) => ResponsiveBreakpoints.builder(
        // En TV, modo "con flechas": las barras (volumen, tiempo) se mueven
        // con izquierda/derecha y arriba/abajo pasan a otro botón.
        child: Tv.isTv
            ? MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(navigationMode: NavigationMode.directional),
                child: ClampingScrollWrapper.builder(context, widget!),
              )
            : ClampingScrollWrapper.builder(context, widget!),
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1200, name: DESKTOP),
          const Breakpoint(start: 1201, end: double.infinity, name: '4K'),
        ],
      ),
    );
  }
}
