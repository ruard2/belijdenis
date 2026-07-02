import 'package:web/web.dart' as web;

class BibleTranslationPreferences {
  static const _key = 'houvast.preferredBibleTranslation';

  static String? load() {
    return web.window.localStorage.getItem(_key);
  }

  static void save(String translation) {
    web.window.localStorage.setItem(_key, translation);
  }
}
