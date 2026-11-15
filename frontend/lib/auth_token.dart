import 'session_storage_stub.dart'
    if (dart.library.html) 'session_storage_web.dart';

/// Gedeelde opslag van het inlogtoken, gebruikt door leerling-app en admin.
class AuthToken {
  static String? value;

  static Map<String, String> headers({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (value != null && value!.isNotEmpty) 'Authorization': 'Bearer $value',
    };
  }

  static String? loadPersisted() => SessionStorage.load();

  static void persist(String sessionJson) => SessionStorage.save(sessionJson);

  static void clear() {
    value = null;
    SessionStorage.clear();
  }
}
