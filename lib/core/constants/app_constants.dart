/// Clase que contiene las constantes de configuración de la aplicación
class AppConstants {
  // ============================================
  // CONFIGURACIÓN DE CATEGORÍAS
  // ============================================

  /// Lista de IDs de categorías permitidas para mostrar en la aplicación
  ///
  /// Solo los artículos de estas categorías se mostrarán en el feed.
  /// Para ocultar una categoría, coméntala o elimínala de esta lista.
  ///
  /// Ejemplo de uso:
  /// - Para mostrar: incluye el ID en la lista
  /// - Para ocultar: comenta la línea con //
  static const List<int> allowedCategoryIds = [
    287, // Noticias
    286, // Lo + Leído
    285, // Lo+oído
    384, // Verde Tierra
    // 7,   // Internacional (comentado = no se mostrará)
    // 220, // Policiales (comentado = no se mostrará)
  ];

  // ============================================
  // NOMBRES DE CATEGORÍAS
  // ============================================

  /// Mapeo de IDs de categorías a sus nombres legibles
  ///
  /// Útil para mostrar nombres de categorías en la interfaz de usuario
  /// sin necesidad de consultar la API cada vez.
  ///
  /// Formato: {id: 'Nombre de la categoría'}
  static const Map<int, String> categoryNames = {
    294: 'Actualidad',
    297: 'De Interés',
    412: 'Destacado',
    300: 'Devocionales',
    285: 'Lo+oído',
    286: 'Lo+Leído',
    287: 'Noticias',
    292: 'Tu Mundo Gospel',
    271: 'Uncategorized',
    384: 'Verde Tierra',
  };
}
