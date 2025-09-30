class Category {
  final int id;
  final String name;
  final String slug;
  final int count;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      count: json['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'count': count,
    };
  }
}