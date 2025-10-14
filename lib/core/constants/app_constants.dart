class AppConstants {
  // ✨ AQUÍ DEFINES LAS CATEGORÍAS QUE QUIERES MOSTRAR
  static const List<int> allowedCategoryIds = [
    287, // Noticias
    286, // Lo + Leído
    285, // Lo+oído
    292, // Tu Mundo Gospel
    // 7,   // Internacional (comentado = no se mostrará)
    // 220, // Policiales (comentado = no se mostrará)
  ];

  // Nombres de las categorías (opcional, para mostrar en UI)
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
  };
}
