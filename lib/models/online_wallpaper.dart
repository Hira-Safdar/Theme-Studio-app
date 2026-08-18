/// A wallpaper that can be downloaded from the internet.
class OnlineWallpaper {
  final String id;
  final String url;
  final String thumbnailUrl;
  final String category;
  final String author;

  const OnlineWallpaper({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.category,
    required this.author,
  });
}
