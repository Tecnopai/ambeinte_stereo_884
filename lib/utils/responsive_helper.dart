import 'package:flutter/material.dart';

/// Helper class global para responsive design.
///
/// Proporciona detección de dispositivos, breakpoints y valores adaptativos
/// para crear interfaces que se adaptan a cualquier tamaño de pantalla (móvil,
/// tablet, desktop y sistemas de infoentretenimiento de vehículos - Automotive).
///
/// Ejemplo de uso:
/// ```dart
/// final responsive = ResponsiveHelper(context);
/// Text('Hola', style: TextStyle(fontSize: responsive.bodyText))
/// ```
class ResponsiveHelper {
  final BuildContext context;

  /// Crea una instancia de [ResponsiveHelper] utilizando el [BuildContext] para
  /// acceder a [MediaQueryData].
  ResponsiveHelper(this.context);

  // ===== PROPIEDADES DE PANTALLA =====

  /// Retorna el [Size] completo de la pantalla.
  Size get screenSize => MediaQuery.of(context).size;

  /// Retorna el ancho de la pantalla.
  double get width => screenSize.width;

  /// Retorna la altura de la pantalla.
  double get height => screenSize.height;

  /// Retorna el lado más corto de la pantalla (útil para detección de tamaño independiente de la orientación).
  double get shortestSide => screenSize.shortestSide;

  /// Retorna el lado más largo de la pantalla.
  double get longestSide => screenSize.longestSide;

  // ===== ORIENTACIÓN =====

  /// True si la pantalla está en landscape (horizontal).
  bool get isLandscape => width > height;

  /// True si la pantalla está en portrait (vertical).
  bool get isPortrait => height >= width;

  // ===== DETECCIÓN DE AUTOMOTIVE =====

  /// Detecta si el dispositivo es un radio de vehículo (Automotive).
  ///
  /// Se considera Automotive si:
  /// - Está en orientación landscape.
  /// - El aspecto ratio es ancho (>= 1.6).
  /// - La altura está dentro de un rango típico para pantallas de vehículos (400px - 900px).
  bool get isAutomotive {
    final aspectRatio = longestSide / shortestSide;
    return isLandscape && aspectRatio >= 1.6 && height >= 400 && height <= 900;
  }

  /// Tipo específico de radio automotive (DIN simple, doble, o grande).
  AutomotiveType get automotiveType {
    if (!isAutomotive) return AutomotiveType.none;
    if (width <= 900 && height <= 550) return AutomotiveType.singleDIN;
    if (width <= 1100 && height <= 700) return AutomotiveType.doubleDIN;
    return AutomotiveType.large;
  }

  // ===== BREAKPOINTS (Basados en shortestSide cuando no es Automotive) =====

  /// Teléfono pequeño (< 360px).
  bool get isSmallPhone => !isAutomotive && shortestSide < 360;

  /// Teléfono normal (360px <= shortestSide < 450px).
  bool get isPhone =>
      !isAutomotive && shortestSide >= 360 && shortestSide < 450;

  /// Teléfono grande (450px <= shortestSide < 600px).
  bool get isLargePhone =>
      !isAutomotive && shortestSide >= 450 && shortestSide < 600;

  /// Tablet pequeña (600px <= shortestSide < 840px).
  bool get isTablet =>
      !isAutomotive && shortestSide >= 600 && shortestSide < 840;

  /// Tablet grande (840px <= shortestSide < 1200px).
  bool get isLargeTablet =>
      !isAutomotive && shortestSide >= 840 && shortestSide < 1200;

  /// Desktop (shortestSide >= 1200px).
  bool get isDesktop => !isAutomotive && shortestSide >= 1200;

  // ===== TIPO DE DISPOSITIVO =====

  /// Retorna el tipo de dispositivo actual, útil para lógica condicional.
  DeviceType get deviceType {
    if (isAutomotive) {
      switch (automotiveType) {
        case AutomotiveType.singleDIN:
          return DeviceType.automotiveSingleDIN;
        case AutomotiveType.doubleDIN:
          return DeviceType.automotiveDoubleDIN;
        case AutomotiveType.large:
          return DeviceType.automotiveLarge;
        default:
          return DeviceType.automotiveDoubleDIN;
      }
    }

    if (isSmallPhone) return DeviceType.smallPhone;
    if (isPhone) return DeviceType.phone;
    if (isLargePhone) return DeviceType.largePhone;
    if (isTablet) return DeviceType.tablet;
    if (isLargeTablet) return DeviceType.largeTablet;
    return DeviceType.desktop;
  }

  // ===== MÉTODO getValue (CORE) =====

  /// Retorna el valor apropiado según el tipo de dispositivo.
  ///
  /// El parámetro [phone] es requerido y se usa como fallback.
  /// Los demás parámetros son opcionales y sobrescriben el valor según el breakpoint.
  ///
  /// Ejemplo:
  /// ```dart
  /// final fontSize = responsive.getValue(
  ///   phone: 14.0,
  ///   largePhone: 16.0,
  ///   tablet: 18.0,
  /// );
  /// ```
  T getValue<T>({
    required T phone,
    T? smallPhone,
    T? largePhone,
    T? tablet,
    T? largeTablet,
    T? desktop,
    T? automotive,
  }) {
    // 1. Prioridad para Automotive
    if (isAutomotive && automotive != null) return automotive;
    // 2. Prioridad para Desktop/Tablets (por tamaño)
    if (isDesktop && desktop != null) return desktop;
    if (isLargeTablet && largeTablet != null) return largeTablet;
    if (isTablet && tablet != null) return tablet;
    // 3. Prioridad para Teléfonos (por tamaño)
    if (isLargePhone && largePhone != null) return largePhone;
    if (isSmallPhone && smallPhone != null) return smallPhone;
    // 4. Fallback: Teléfono normal
    return phone;
  }

  // ===== TAMAÑOS DE FUENTE PREDEFINIDOS =====

  /// Tamaño de texto del cuerpo (14-18px). Tamaño mínimo accesible para lectura.
  double get bodyText => getValue(
    smallPhone: 13.0,
    phone: 14.0,
    largePhone: 14.5,
    tablet: 16.0,
    desktop: 18.0,
    automotive: 18.0,
  );

  /// Tamaño de texto pequeño/caption (11-16px). Para metadatos, fechas, labels.
  double get caption => getValue(
    smallPhone: 11.0,
    phone: 12.0,
    largePhone: 12.5,
    tablet: 14.0,
    desktop: 16.0,
    automotive: 16.0,
  );

  /// Tamaño de encabezado grande H1 (22-40px). Para títulos principales.
  double get h1 => getValue(
    smallPhone: 20.0,
    phone: 22.0,
    largePhone: 24.0,
    tablet: 28.0,
    desktop: 32.0,
    automotive: 28.0,
  );

  /// Tamaño de encabezado H2 (18-28px). Para subtítulos importantes.
  double get h2 => getValue(
    smallPhone: 16.0,
    phone: 18.0,
    largePhone: 19.0,
    tablet: 22.0,
    desktop: 24.0,
    automotive: 22.0,
  );

  /// Tamaño de encabezado H3 (15-24px). Para secciones y subsecciones.
  double get h3 => getValue(
    smallPhone: 14.0,
    phone: 16.0,
    largePhone: 17.0,
    tablet: 18.0,
    desktop: 20.0,
    automotive: 18.0,
  );

  /// Tamaño de texto de botones (12-20px).
  double get buttonText => getValue(
    smallPhone: 12.0,
    phone: 14.0,
    largePhone: 14.5,
    tablet: 16.0,
    desktop: 18.0,
    automotive: 18.0,
  );

  // ===== ESPACIADOS =====

  /// Calcula espaciado vertical/horizontal adaptativo.
  ///
  /// Multiplica el valor [base] según el factor de escala del dispositivo:
  /// - Phone: 1.0x
  /// - Large Phone: 1.1x
  /// - Tablet: 1.2x
  /// - Desktop: 1.5x
  /// - Automotive: 0.8x (más compacto en vehículos)
  ///
  /// Ejemplo:
  /// ```dart
  /// SizedBox(height: responsive.spacing(24)) // 24-36px según dispositivo
  /// ```
  double spacing(double base) => getValue(
    phone: base,
    largePhone: base * 1.1,
    tablet: base * 1.2,
    desktop: base * 1.5,
    automotive: base * 0.8,
  );

  // ===== LAYOUT =====

  /// Ancho máximo de contenido para evitar líneas de texto excesivamente largas
  /// en pantallas grandes, manteniendo el enfoque de lectura.
  ///
  /// - Móviles: [double.infinity] (usa todo el ancho)
  /// - Tablets: 720-900px
  /// - Desktop: 1100px
  double get maxContentWidth => getValue(
    phone: double.infinity,
    largePhone: double.infinity,
    tablet: 720.0,
    largeTablet: 900.0,
    desktop: 1100.0,
    automotive: double.infinity,
  );

  /// Número de columnas sugerido para [GridView] o layouts basados en filas.
  ///
  /// - Móviles: 1 columna (lista)
  /// - Tablets: 2-3 columnas
  /// - Desktop: 3 columnas
  int get gridColumns => getValue(
    phone: 1,
    largePhone: 1,
    tablet: 2,
    largeTablet: 3,
    desktop: 3,
    automotive: 2,
  );

  /// Determina si debe usar [NavigationRail] en lugar de [BottomNavigationBar].
  ///
  /// Se recomienda NavigationRail para pantallas no móviles, especialmente en landscape
  /// y siempre en modo Automotive.
  bool get useNavigationRail {
    if (isAutomotive) return true;
    if ((isTablet || isLargeTablet || isDesktop) && isLandscape) return true;
    return false;
  }
}

// ===== ENUMS =====

/// Tipos de dispositivos soportados, agrupados por rangos de [shortestSide].
enum DeviceType {
  /// Teléfono pequeño ([shortestSide] < 360px)
  smallPhone,

  /// Teléfono normal (360px <= [shortestSide] < 450px)
  phone,

  /// Teléfono grande (450px <= [shortestSide] < 600px)
  largePhone,

  /// Tablet pequeña (600px <= [shortestSide] < 840px)
  tablet,

  /// Tablet grande (840px <= [shortestSide] < 1200px)
  largeTablet,

  /// Desktop ([shortestSide] >= 1200px)
  desktop,

  /// Radio de vehículo DIN simple (~800x480)
  automotiveSingleDIN,

  /// Radio de vehículo DIN doble (~1024x600)
  automotiveDoubleDIN,

  /// Radio de vehículo grande (~1280x720+)
  automotiveLarge,
}

/// Tipos de radios automotive específicos, clasificados por tamaño.
enum AutomotiveType {
  /// No es automotive
  none,

  /// DIN simple (~800x480)
  singleDIN,

  /// DIN doble (~1024x600) - Más común
  doubleDIN,

  /// Pantalla grande (~1280x720+)
  large,
}
