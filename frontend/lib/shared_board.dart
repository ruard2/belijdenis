import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'auth_token.dart';
import 'main.dart' show apiBaseUrl, AppSession;

/// Eén item op een gedeeld bord (reactie, emoji, verdeling, post, aantekening).
class BoardItem {
  BoardItem({
    required this.id,
    required this.kind,
    required this.key,
    required this.userId,
    required this.username,
    required this.data,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final String key;
  final String userId;
  final String username;
  final Map<String, dynamic> data;
  final String createdAt;

  bool get isMine => userId == AppSession.current?.userId;

  factory BoardItem.fromJson(Map<String, dynamic> json) => BoardItem(
    id: (json['id'] as num).toInt(),
    kind: json['kind'] as String,
    key: json['key'] as String? ?? '',
    userId: json['user_id'] as String,
    username: json['username'] as String,
    data: (json['data'] as Map).cast<String, dynamic>(),
    createdAt: json['created_at'] as String? ?? '',
  );
}

class BoardApi {
  static Future<List<BoardItem>> list(String scope) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/board').replace(queryParameters: {'scope': scope}),
      headers: AuthToken.headers(),
    );
    _ensureOk(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => BoardItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<BoardItem> put(
    String scope,
    String kind,
    Map<String, dynamic> data, {
    String? key,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/board'),
      headers: AuthToken.headers(json: true),
      body: jsonEncode({
        'scope': scope,
        'kind': kind,
        if (key != null) 'key': key,
        'data': data,
      }),
    );
    _ensureOk(response);
    return BoardItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deleteKey(String scope, String kind, String key) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/board').replace(
        queryParameters: {'scope': scope, 'kind': kind, 'key': key},
      ),
      headers: AuthToken.headers(),
    );
    _ensureOk(response);
  }

  static Future<void> deleteItem(int id) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/board/items/$id'),
      headers: AuthToken.headers(),
    );
    _ensureOk(response);
  }

  /// Uploadt een bestand en geeft de (absolute) URL terug.
  static Future<String> upload(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBaseUrl/uploads'),
    );
    request.headers.addAll(AuthToken.headers());
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final response = await http.Response.fromStream(await request.send());
    _ensureOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return '$apiBaseUrl${body['url']}';
  }

  static void _ensureOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Er ging iets mis (${response.statusCode}).';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] is String) {
          message = body['detail'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }
  }
}

/// Houdt de items van één scope bij en ververst ze periodiek.
class SharedBoardController extends ChangeNotifier with WidgetsBindingObserver {
  SharedBoardController(
    this.scope, {
    Duration refresh = const Duration(seconds: 15),
  }) {
    load();
    _timer = Timer.periodic(refresh, (_) => load());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Terug in de app (tab/telefoon weer actief): meteen verversen.
    if (state == AppLifecycleState.resumed) load();
  }

  final String scope;
  Timer? _timer;
  List<BoardItem> items = [];
  bool loaded = false;
  String? error;
  bool _disposed = false;

  Iterable<BoardItem> ofKind(String kind) =>
      items.where((item) => item.kind == kind);

  BoardItem? mine(String kind, String key) {
    for (final item in items) {
      if (item.kind == kind && item.key == key && item.isMine) return item;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final next = await BoardApi.list(scope);
      if (_disposed) return;
      items = next;
      loaded = true;
      error = null;
      notifyListeners();
    } catch (exception) {
      if (_disposed) return;
      error = '$exception'.replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<BoardItem> put(
    String kind,
    Map<String, dynamic> data, {
    String? key,
  }) async {
    final item = await BoardApi.put(scope, kind, data, key: key);
    if (_disposed) return item;
    items = [
      ...items.where(
        (existing) =>
            !(existing.id == item.id ||
                (key != null &&
                    existing.kind == kind &&
                    existing.key == key &&
                    existing.isMine)),
      ),
      item,
    ];
    notifyListeners();
    return item;
  }

  Future<void> removeKey(String kind, String key) async {
    await BoardApi.deleteKey(scope, kind, key);
    if (_disposed) return;
    items = items
        .where((item) => !(item.kind == kind && item.key == key && item.isMine))
        .toList();
    notifyListeners();
  }

  Future<void> removeItem(BoardItem target) async {
    await BoardApi.deleteItem(target.id);
    if (_disposed) return;
    items = items.where((item) => item.id != target.id).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
