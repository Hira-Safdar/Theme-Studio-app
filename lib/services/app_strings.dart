// lib/services/app_strings.dart
//
// Lightweight in-house translation lookup -- deliberately NOT using
// Flutter's ARB/gen-l10n tooling, since that needs a code-gen build step
// that's easy to break mid-development. This is a plain Map lookup: add
// a key here once, use `tr('key')` anywhere in the UI.
//
// COVERAGE NOTE: this first pass covers the app shell (bottom nav labels,
// each screen's AppBar title) and the full Settings screen -- the two
// places most likely to be seen right after switching language, so the
// change is immediately obvious. The longer explainer paragraphs (Icon
// changer/Widgets/Control Center "how it works" bodies) and in-screen
// content are still English-only for now; extending translation to them
// is the same pattern (wrap the string in `tr('new_key')` + add the key
// to all 4 maps below) and can be done incrementally.
import 'locale_controller.dart';

const Map<String, Map<String, String>> _strings = {
  'en': {
    'nav_home': 'Home',
    'nav_wallpaper': 'Wallpaper',
    'nav_icons': 'Icons',
    'nav_widgets': 'Widgets',
    'nav_control': 'Control',

    'app_title': 'Theme studio',
    'wallpaper_title': 'Wallpaper',
    'icon_changer_title': 'Icon changer',
    'widgets_title': 'Widgets',
    'control_center_title': 'Control Center',
    'splash_setting_up': 'Setting things up…',

    'home_instruction':
        'Select a theme — wallpaper and icon pack will be applied together.',

    'settings_title': 'Settings',
    'settings_section_general': 'General',
    'settings_section_help': 'Help',
    'settings_section_about': 'About',
    'settings_language': 'Language',
    'settings_how_icons': 'How icon shortcuts work',
    'settings_how_widgets': 'How widgets work',
    'settings_how_control': 'How Control Center works',
    'settings_send_feedback': 'Send feedback',
    'settings_privacy': 'Privacy policy',
    'settings_rate': 'Rate the app',
    'settings_version': 'Version',
    'search_apps_hint': 'Search apps…',
    'search_no_results': 'No apps match your search',
    'widget_font_size': 'Font size',
    'widget_text_color': 'Text color',
    'widget_bg_opacity': 'Background opacity',
    'widget_corner_radius': 'Corner radius',
    'favorites_filter': 'Favorites',
    'favorites_empty': 'No favorites yet — tap the heart icon on a theme.',
    'settings_dark_mode': 'Dark mode',
    'online_tab': 'Online',
    'online_themes': 'Themes',
    'online_icon_packs': 'Icon Packs',
    'search_wallpapers_hint': 'Search wallpapers…',
    'all_categories': 'All',
    'my_tab': 'My',
    'import_gallery': 'Import from gallery',
    'my_wallpapers_empty': 'Tap + to import wallpapers from your gallery.\nThey\'ll appear here for easy access.',
    'wallpaper_applied': 'Wallpaper applied',
    'wallpaper_failed': 'Couldn\'t apply wallpaper',
    'no_wallpapers_found': 'No wallpapers found',
    'action_cancel': 'Cancel',
    'action_save': 'Save',
  },
  'ur': {
    'nav_home': 'ہوم',
    'nav_wallpaper': 'وال پیپر',
    'nav_icons': 'آئیکنز',
    'nav_widgets': 'ویجٹس',
    'nav_control': 'کنٹرول',

    'app_title': 'تھیم اسٹوڈیو',
    'wallpaper_title': 'وال پیپر',
    'icon_changer_title': 'آئیکن چینجر',
    'widgets_title': 'ویجٹس',
    'control_center_title': 'کنٹرول سینٹر',
    'splash_setting_up': 'تیار ہو رہا ہے…',

    'home_instruction': 'ایک تھیم منتخب کریں — وال پیپر اور آئیکن پیک ایک ساتھ لاگو ہوں گے۔',

    'settings_title': 'ترتیبات',
    'settings_section_general': 'عمومی',
    'settings_section_help': 'مدد',
    'settings_section_about': 'ایپ کے بارے میں',
    'settings_language': 'زبان',
    'settings_how_icons': 'آئیکن شارٹ کٹس کیسے کام کرتے ہیں',
    'settings_how_widgets': 'ویجٹس کیسے کام کرتے ہیں',
    'settings_how_control': 'کنٹرول سینٹر کیسے کام کرتا ہے',
    'settings_send_feedback': 'رائے بھیجیں',
    'settings_privacy': 'رازداری کی پالیسی',
    'settings_rate': 'ایپ کو ریٹ کریں',
    'settings_version': 'ورژن',
    'search_apps_hint': 'ایپس تلاش کریں…',
    'search_no_results': 'کوئی ایپ نہیں ملی',
    'widget_font_size': 'فونٹ سائز',
    'widget_text_color': 'متن کا رنگ',
    'widget_bg_opacity': 'پس منظر کی شفافیت',
    'widget_corner_radius': 'کونے کی گولائی',
    'favorites_filter': 'پسندیدہ',
    'favorites_empty': 'ابھی تک کوئی پسندیدہ نہیں — تھیم پر دل کے آئیکن پر ٹیپ کریں۔',
    'settings_dark_mode': 'ڈارک موڈ',
    'online_tab': 'آن لائن',
    'online_themes': 'تھیمز',
    'online_icon_packs': 'آئیکن پیکس',
    'search_wallpapers_hint': 'وال پیپر تلاش کریں…',
    'action_cancel': 'منسوخ',
    'action_save': 'محفوظ کریں',
  },
  'es': {
    'nav_home': 'Inicio',
    'nav_wallpaper': 'Fondo',
    'nav_icons': 'Iconos',
    'nav_widgets': 'Widgets',
    'nav_control': 'Control',

    'app_title': 'Theme studio',
    'wallpaper_title': 'Fondo de pantalla',
    'icon_changer_title': 'Cambiar iconos',
    'widgets_title': 'Widgets',
    'control_center_title': 'Centro de control',
    'splash_setting_up': 'Preparando todo…',

    'home_instruction':
        'Elige un tema — el fondo de pantalla y el paquete de iconos se aplicarán juntos.',

    'settings_title': 'Ajustes',
    'settings_section_general': 'General',
    'settings_section_help': 'Ayuda',
    'settings_section_about': 'Acerca de',
    'settings_language': 'Idioma',
    'settings_how_icons': 'Cómo funcionan los accesos directos de iconos',
    'settings_how_widgets': 'Cómo funcionan los widgets',
    'settings_how_control': 'Cómo funciona el Centro de control',
    'settings_send_feedback': 'Enviar comentarios',
    'settings_privacy': 'Política de privacidad',
    'settings_rate': 'Valorar la app',
    'settings_version': 'Versión',
    'search_apps_hint': 'Buscar apps…',
    'search_no_results': 'Ninguna app coincide',
    'widget_font_size': 'Tamaño de fuente',
    'widget_text_color': 'Color del texto',
    'widget_bg_opacity': 'Opacidad de fondo',
    'widget_corner_radius': 'Radio de esquina',
    'favorites_filter': 'Favoritos',
    'favorites_empty': 'Sin favoritos aún — toca el corazón en un tema.',
    'settings_dark_mode': 'Modo oscuro',
    'online_tab': 'En línea',
    'online_themes': 'Temas',
    'online_icon_packs': 'Paquetes de iconos',
    'search_wallpapers_hint': 'Buscar fondos…',
    'action_cancel': 'Cancelar',
    'action_save': 'Guardar',
  },
  'fr': {
    'nav_home': 'Accueil',
    'nav_wallpaper': "Fond d'écran",
    'nav_icons': 'Icônes',
    'nav_widgets': 'Widgets',
    'nav_control': 'Contrôle',

    'app_title': 'Theme studio',
    'wallpaper_title': "Fond d'écran",
    'icon_changer_title': "Changer d'icônes",
    'widgets_title': 'Widgets',
    'control_center_title': 'Centre de contrôle',
    'splash_setting_up': 'Préparation en cours…',

    'home_instruction':
        "Choisissez un thème — le fond d'écran et le pack d'icônes seront appliqués ensemble.",

    'settings_title': 'Paramètres',
    'settings_section_general': 'Général',
    'settings_section_help': 'Aide',
    'settings_section_about': 'À propos',
    'settings_language': 'Langue',
    'settings_how_icons': "Comment fonctionnent les raccourcis d'icônes",
    'settings_how_widgets': 'Comment fonctionnent les widgets',
    'settings_how_control': 'Comment fonctionne le Centre de contrôle',
    'settings_send_feedback': 'Envoyer des commentaires',
    'settings_privacy': 'Politique de confidentialité',
    'settings_rate': "Évaluer l'application",
    'settings_version': 'Version',
    'search_apps_hint': 'Rechercher…',
    'search_no_results': 'Aucune application trouvée',
    'widget_font_size': 'Taille de police',
    'widget_text_color': 'Couleur du texte',
    'widget_bg_opacity': 'Opacité du fond',
    'widget_corner_radius': 'Rayon de coin',
    'favorites_filter': 'Favoris',
    'favorites_empty': 'Pas encore de favoris — appuyez sur le cœur sur un thème.',
    'settings_dark_mode': 'Mode sombre',
    'online_tab': 'En ligne',
    'online_themes': 'Thèmes',
    'online_icon_packs': "Pack d'icônes",
    'search_wallpapers_hint': 'Rechercher des fonds…',
    'action_cancel': 'Annuler',
    'action_save': 'Enregistrer',
  },
};

/// Current language ke hisaab se translated string deta hai. Key kisi
/// bhi language mein na mile to English fallback, wo bhi na ho to key
/// khud return ho jaati hai (crash kabhi nahi hoga, worst case English
/// ya raw key dikhega).
String tr(String key) {
  final code = LocaleController.instance.languageCode;
  return _strings[code]?[key] ?? _strings['en']?[key] ?? key;
}