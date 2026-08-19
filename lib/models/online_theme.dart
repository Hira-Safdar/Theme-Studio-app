class OnlineTheme {
  final String id;
  final String name;
  final String category;
  final String searchQuery;
  final int accentColorValue;

  const OnlineTheme({
    required this.id,
    required this.name,
    required this.category,
    required this.searchQuery,
    this.accentColorValue = 0xFF00FFF0,
  });

  static const List<OnlineTheme> curated = [
    OnlineTheme(id: 'nature', name: 'Nature', category: 'nature', searchQuery: 'nature landscape wallpaper', accentColorValue: 0xFF4E9E6B),
    OnlineTheme(id: 'forest', name: 'Forest', category: 'nature', searchQuery: 'forest trees wallpaper', accentColorValue: 0xFF2E7D32),
    OnlineTheme(id: 'ocean', name: 'Ocean', category: 'nature', searchQuery: 'ocean sea waves wallpaper', accentColorValue: 0xFF2AA9C4),
    OnlineTheme(id: 'space', name: 'Space', category: 'cosmic', searchQuery: 'space galaxy nebula wallpaper', accentColorValue: 0xFF5B4B9E),
    OnlineTheme(id: 'sunset', name: 'Sunset', category: 'cosmic', searchQuery: 'sunset sky clouds wallpaper', accentColorValue: 0xFFE8875A),
    OnlineTheme(id: 'minimal', name: 'Minimal', category: 'abstract', searchQuery: 'minimal abstract wallpaper', accentColorValue: 0xFFBDBDBD),
    OnlineTheme(id: 'dark', name: 'Dark', category: 'abstract', searchQuery: 'dark moody abstract wallpaper', accentColorValue: 0xFF00FFF0),
    OnlineTheme(id: 'pastel', name: 'Pastel', category: 'abstract', searchQuery: 'pastel aesthetic wallpaper', accentColorValue: 0xFFD8698C),
    OnlineTheme(id: 'city', name: 'City', category: 'cosmic', searchQuery: 'city skyline night wallpaper', accentColorValue: 0xFFE8875A),
  ];

  static List<String> get categories {
    final cats = <String>{};
    for (final t in curated) {
      cats.add(t.category);
    }
    return cats.toList();
  }

  static List<OnlineTheme> byCategory(String cat) {
    return curated.where((t) => t.category == cat).toList();
  }
}
