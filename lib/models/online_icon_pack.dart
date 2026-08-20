/// An online icon pack — name + URLs for icon images mapped to package names.
class OnlineIconPack {
  final String id;
  final String name;
  final String author;
  final String description;
  final Map<String, String> iconUrls;

  const OnlineIconPack({
    required this.id,
    required this.name,
    required this.author,
    required this.description,
    required this.iconUrls,
  });

  int get iconCount => iconUrls.length;

  factory OnlineIconPack.fromJson(Map<String, dynamic> json) {
    return OnlineIconPack(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      iconUrls: Map<String, String>.from(json['icons'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author': author,
        'description': description,
        'icons': iconUrls,
      };

  /// Empty — all packs now live in assets/pack_catalog.json.
  static const List<OnlineIconPack> curated = [];
}
