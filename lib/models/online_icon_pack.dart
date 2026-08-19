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

  /// Curated icon packs with direct image URLs (free to use).
  static const List<OnlineIconPack> curated = [
    OnlineIconPack(
      id: 'neon_glow',
      name: 'Neon Glow',
      author: 'Theme Studio',
      description: 'Vibrant neon-style icons with glow effects',
      iconUrls: {
        'com.google.android.gm': 'https://img.icons8.com/fluency/96/gmail.png',
        'com.google.android.apps.maps': 'https://img.icons8.com/fluency/96/google-maps.png',
        'com.whatsapp': 'https://img.icons8.com/fluency/96/whatsapp.png',
        'com.instagram.android': 'https://img.icons8.com/fluency/96/instagram.png',
        'com.twitter.android': 'https://img.icons8.com/fluency/96/twitter.png',
        'com.spotify.music': 'https://img.icons8.com/fluency/96/spotify.png',
        'com.google.android.youtube': 'https://img.icons8.com/fluency/96/youtube.png',
        'com.facebook.katana': 'https://img.icons8.com/fluency/96/facebook-new.png',
        'com.google.android.apps.photos': 'https://img.icons8.com/fluency/96/google-photos.png',
        'com.google.android.calendar': 'https://img.icons8.com/fluency/96/google-calendar.png',
        'com.google.android.apps.docs': 'https://img.icons8.com/fluency/96/google-docs.png',
        'com.google.android.gmm': 'https://img.icons8.com/fluency/96/google-maps.png',
        'com.android.chrome': 'https://img.icons8.com/fluency/96/chrome.png',
        'com.google.android.dialer': 'https://img.icons8.com/fluency/96/phone.png',
        'com.google.android.contacts': 'https://img.icons8.com/fluency/96/contacts.png',
        'com.google.android.apps.messaging': 'https://img.icons8.com/fluency/96/sms.png',
        'com.google.android.calculator': 'https://img.icons8.com/fluency/96/calculator.png',
        'com.google.android.apps.clock': 'https://img.icons8.com/fluency/96/clock.png',
        'com.google.android.apps.magazines': 'https://img.icons8.com/fluency/96/google-news.png',
        'com.google.android.apps.playbooks': 'https://img.icons8.com/fluency/96/google-play-books.png',
      },
    ),
    OnlineIconPack(
      id: 'pastel_dream',
      name: 'Pastel Dream',
      author: 'Theme Studio',
      description: 'Soft pastel-colored icons',
      iconUrls: {
        'com.google.android.gm': 'https://img.icons8.com/dusk/96/gmail.png',
        'com.whatsapp': 'https://img.icons8.com/dusk/96/whatsapp.png',
        'com.instagram.android': 'https://img.icons8.com/dusk/96/instagram.png',
        'com.spotify.music': 'https://img.icons8.com/dusk/96/spotify.png',
        'com.google.android.youtube': 'https://img.icons8.com/dusk/96/youtube.png',
        'com.facebook.katana': 'https://img.icons8.com/dusk/96/facebook-new.png',
        'com.google.android.apps.photos': 'https://img.icons8.com/dusk/96/google-photos.png',
        'com.google.android.calendar': 'https://img.icons8.com/dusk/96/google-calendar.png',
        'com.android.chrome': 'https://img.icons8.com/dusk/96/chrome.png',
        'com.google.android.dialer': 'https://img.icons8.com/dusk/96/phone.png',
        'com.google.android.contacts': 'https://img.icons8.com/dusk/96/contacts.png',
        'com.google.android.apps.messaging': 'https://img.icons8.com/dusk/96/sms.png',
        'com.google.android.calculator': 'https://img.icons8.com/dusk/96/calculator.png',
        'com.google.android.apps.clock': 'https://img.icons8.com/dusk/96/clock.png',
        'com.google.android.apps.docs': 'https://img.icons8.com/dusk/96/google-docs.png',
      },
    ),
    OnlineIconPack(
      id: 'line_black',
      name: 'Line Black',
      author: 'Theme Studio',
      description: 'Clean line-art style icons on dark backgrounds',
      iconUrls: {
        'com.google.android.gm': 'https://img.icons8.com/ios-filled/96/gmail.png',
        'com.whatsapp': 'https://img.icons8.com/ios-filled/96/whatsapp.png',
        'com.instagram.android': 'https://img.icons8.com/ios-filled/96/instagram.png',
        'com.spotify.music': 'https://img.icons8.com/ios-filled/96/spotify.png',
        'com.google.android.youtube': 'https://img.icons8.com/ios-filled/96/youtube.png',
        'com.facebook.katana': 'https://img.icons8.com/ios-filled/96/facebook-new.png',
        'com.google.android.apps.photos': 'https://img.icons8.com/ios-filled/96/google-photos.png',
        'com.android.chrome': 'https://img.icons8.com/ios-filled/96/chrome.png',
        'com.google.android.dialer': 'https://img.icons8.com/ios-filled/96/phone.png',
        'com.google.android.contacts': 'https://img.icons8.com/ios-filled/96/contacts.png',
        'com.google.android.apps.messaging': 'https://img.icons8.com/ios-filled/96/sms.png',
        'com.google.android.calculator': 'https://img.icons8.com/ios-filled/96/calculator.png',
        'com.google.android.apps.clock': 'https://img.icons8.com/ios-filled/96/clock.png',
      },
    ),
  ];
}
