import '../models/online_wallpaper.dart';

/// Curated list of free-to-use wallpapers. Each has a direct image URL
/// and a thumbnail (smaller version for grid display). Extensible —
/// later this can be swapped for a real API backend.
const List<OnlineWallpaper> curatedOnlineWallpapers = [
  OnlineWallpaper(
    id: 'on_01',
    url: 'https://picsum.photos/id/1015/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1015/400/700',
    category: 'nature',
    author: 'Paul Jarvis',
  ),
  OnlineWallpaper(
    id: 'on_02',
    url: 'https://picsum.photos/id/1018/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1018/400/700',
    category: 'nature',
    author: 'Aleks Dorohovich',
  ),
  OnlineWallpaper(
    id: 'on_03',
    url: 'https://picsum.photos/id/1039/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1039/400/700',
    category: 'nature',
    author: 'Niels SteenVinkel',
  ),
  OnlineWallpaper(
    id: 'on_04',
    url: 'https://picsum.photos/id/1043/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1043/400/700',
    category: 'abstract',
    author: 'Dave Patrick',
  ),
  OnlineWallpaper(
    id: 'on_05',
    url: 'https://picsum.photos/id/1047/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1047/400/700',
    category: 'abstract',
    author: 'Ioan Sameli',
  ),
  OnlineWallpaper(
    id: 'on_06',
    url: 'https://picsum.photos/id/1057/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1057/400/700',
    category: 'abstract',
    author: 'Hans Peter Meyer',
  ),
  OnlineWallpaper(
    id: 'on_07',
    url: 'https://picsum.photos/id/1050/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1050/400/700',
    category: 'dark',
    author: 'Bailey Zindel',
  ),
  OnlineWallpaper(
    id: 'on_08',
    url: 'https://picsum.photos/id/1055/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1055/400/700',
    category: 'dark',
    author: 'luca bravo',
  ),
  OnlineWallpaper(
    id: 'on_09',
    url: 'https://picsum.photos/id/1067/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1067/400/700',
    category: 'dark',
    author: 'Anton Repponen',
  ),
  OnlineWallpaper(
    id: 'on_10',
    url: 'https://picsum.photos/id/1069/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1069/400/700',
    category: 'minimal',
    author: 'Annie Spratt',
  ),
  OnlineWallpaper(
    id: 'on_11',
    url: 'https://picsum.photos/id/1076/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1076/400/700',
    category: 'minimal',
    author: 'Adam Wilson',
  ),
  OnlineWallpaper(
    id: 'on_12',
    url: 'https://picsum.photos/id/1080/1080/1920',
    thumbnailUrl: 'https://picsum.photos/id/1080/400/700',
    category: 'minimal',
    author: ' Scott Webb',
  ),
];
