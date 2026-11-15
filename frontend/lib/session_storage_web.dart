import 'package:web/web.dart' as web;

class SessionStorage {
  static const _key = 'houvast.session';

  static String? load() {
    try {
      return web.window.localStorage.getItem(_key);
    } catch (_) {
      return null;
    }
  }

  static void save(String value) {
    try {
      web.window.localStorage.setItem(_key, value);
    } catch (_) {}
  }

  static void clear() {
    try {
      web.window.localStorage.removeItem(_key);
    } catch (_) {}
  }
}
