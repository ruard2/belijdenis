import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'admin_builder.dart';
import 'bible_translation_preferences_stub.dart'
    if (dart.library.html) 'bible_translation_preferences_web.dart';
import 'youtube_embed_stub.dart'
    if (dart.library.html) 'youtube_embed_web.dart';

const _configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

final String apiBaseUrl = _resolveApiBaseUrl();

String _resolveApiBaseUrl() {
  if (_configuredApiBaseUrl.isNotEmpty) {
    return _configuredApiBaseUrl;
  }
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.startsWith('http://127.0.0.1') ||
        origin.startsWith('http://localhost')) {
      return 'http://127.0.0.1:8000';
    }
    return origin;
  }
  return 'http://127.0.0.1:8000';
}

void main() {
  runApp(const HouvastApp());
}

class HouvastApp extends StatelessWidget {
  const HouvastApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF24302F);
    const sage = Color(0xFF5F7A6A);
    const warm = Color(0xFFF7F3EA);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Houvast',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: sage,
          brightness: Brightness.light,
          surface: warm,
        ),
        scaffoldBackgroundColor: warm,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
          headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: ink),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
          bodyLarge: TextStyle(height: 1.45, color: ink),
          bodyMedium: TextStyle(height: 1.45, color: ink),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE3DED2)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HouvastApi {
  Future<AppSession> loginGuest({String? name}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/guest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name ?? ''}),
    );
    _ensureOk(response);
    return AppSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AppSession> loginAdmin(String password) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/admin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    _ensureOk(response);
    return AppSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<dynamic>> getCourses() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/courses'));
    _ensureOk(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<List<dynamic>> getChapters(String courseId) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/courses/$courseId/chapters'),
    );
    _ensureOk(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getChapter(String chapterId) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/chapters/$chapterId'),
    );
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getBibleTranslations() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/bible/translations'),
    );
    _ensureOk(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getBiblePassage({
    required String reference,
    required String translation,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/bible/passage').replace(
      queryParameters: {'reference': reference, 'translation': translation},
    );
    final response = await http.get(uri);
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> recordActivity({
    required String courseId,
    required String chapterId,
    required String blockId,
    required String blockType,
    required String action,
    required Map<String, dynamic> value,
  }) async {
    final session = AppSession.current;
    if (session == null) return;

    final response = await http.post(
      Uri.parse('$apiBaseUrl/activity'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': session.sessionId,
        'user_id': session.userId,
        'username': session.username,
        'role': session.role,
        'course_id': courseId,
        'chapter_id': chapterId,
        'block_id': blockId,
        'block_type': blockType,
        'action': action,
        'value': value,
      }),
    );
    _ensureOk(response);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API fout ${response.statusCode}: ${response.body}');
    }
  }
}

class AppSession {
  AppSession({
    required this.sessionId,
    required this.userId,
    required this.username,
    required this.role,
  });

  final String sessionId;
  final String userId;
  final String username;
  final String role;

  bool get isAdmin => role == 'admin';
  bool get isGuest => role == 'guest';

  static AppSession? current;

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
    );
  }
}

class ActivityTracker {
  ActivityTracker(this.context);

  final BlockContext context;
  final HouvastApi _api = HouvastApi();

  Future<void> track(String action, Map<String, dynamic> value) async {
    if (_marksBlockComplete(action, value)) {
      LessonProgress.instance.markComplete(context);
    }
    try {
      await _api.recordActivity(
        courseId: context.courseId,
        chapterId: context.chapterId,
        blockId: context.blockId,
        blockType: context.blockType,
        action: action,
        value: value,
      );
    } catch (_) {
      // Activity should never interrupt the lesson flow.
    }
  }

  bool _marksBlockComplete(String action, Map<String, dynamic> value) {
    if (value['completed'] == true || value['block_completed'] == true) {
      return true;
    }
    return {
      'distribution_submitted',
      'challenge_submitted',
      'multiple_choice_selected',
      'statement_response_answered',
      'slider_changed',
      'media_canvas_posted',
      'bible_read',
    }.contains(action);
  }
}

class BlockContext {
  const BlockContext({
    required this.courseId,
    required this.chapterId,
    required this.blockId,
    required this.blockType,
  });

  final String courseId;
  final String chapterId;
  final String blockId;
  final String blockType;
}

class LessonProgress extends ChangeNotifier {
  LessonProgress._();

  static final LessonProgress instance = LessonProgress._();

  final Set<String> _completed = {};

  bool isComplete(String chapterId, String blockId) {
    return _completed.contains(_key(chapterId, blockId));
  }

  bool isContextComplete(BlockContext context) {
    return isComplete(context.chapterId, context.blockId);
  }

  void markComplete(BlockContext context) {
    if (context.chapterId.isEmpty || context.blockId.isEmpty) return;
    if (_completed.add(_key(context.chapterId, context.blockId))) {
      notifyListeners();
    }
  }

  void clear() {
    if (_completed.isEmpty) return;
    _completed.clear();
    notifyListeners();
  }

  int completedCount(
    String chapterId,
    Iterable<MapEntry<int, Map<String, dynamic>>> entries,
  ) {
    return entries
        .where(
          (entry) => isComplete(chapterId, entry.value['id'] as String? ?? ''),
        )
        .length;
  }

  String _key(String chapterId, String blockId) => '$chapterId::$blockId';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final api = HouvastApi();

  bool loading = true;
  String? error;
  List<dynamic> courses = [];
  List<dynamic> chapters = [];
  Map<String, dynamic>? selectedCourse;
  Map<String, dynamic>? selectedChapter;
  AppSession? session;
  bool adminMode = false;

  @override
  void initState() {
    super.initState();
    loading = false;
  }

  Future<void> _setSession(AppSession nextSession) async {
    AppSession.current = nextSession;
    LessonProgress.instance.clear();
    setState(() {
      session = nextSession;
      loading = true;
    });
    await loadInitialData();
  }

  void _logout() {
    AppSession.current = null;
    LessonProgress.instance.clear();
    setState(() {
      session = null;
      adminMode = false;
      selectedChapter = null;
      courses = [];
      chapters = [];
      selectedCourse = null;
    });
  }

  Future<void> _openAdmin() async {
    if (session?.isAdmin == true) {
      setState(() => adminMode = true);
      return;
    }

    final adminSession = await showDialog<AppSession>(
      context: context,
      builder: (_) => const AdminLoginDialog(),
    );
    if (adminSession == null) return;
    await _setSession(adminSession);
    setState(() => adminMode = true);
  }

  Future<void> loadInitialData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loadedCourses = await api.getCourses();
      final firstCourse = loadedCourses.firstOrNull as Map<String, dynamic>?;
      final loadedChapters = firstCourse == null
          ? <dynamic>[]
          : await api.getChapters(firstCourse['id'] as String);

      setState(() {
        courses = loadedCourses;
        selectedCourse = firstCourse;
        chapters = loadedChapters;
        loading = false;
      });
    } catch (exception) {
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  Future<void> openChapter(String chapterId) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final chapter = await api.getChapter(chapterId);
      await api.recordActivity(
        courseId: chapter['course_id'] as String? ?? '',
        chapterId: chapter['id'] as String? ?? chapterId,
        blockId: '',
        blockType: 'chapter',
        action: 'chapter_opened',
        value: {'title': chapter['title'] as String? ?? ''},
      );
      setState(() {
        selectedChapter = chapter;
        loading = false;
      });
    } catch (exception) {
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  void closeChapter() {
    setState(() => selectedChapter = null);
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return Scaffold(
        body: SafeArea(
          child: LoginScreen(api: api, onLogin: _setSession),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!adminMode)
              AppTopBar(
                session: session!,
                onAdmin: _openAdmin,
                onLogout: _logout,
              ),
            Expanded(
              child: adminMode
                  ? AdminBuilder(
                      onClose: () async {
                        setState(() {
                          adminMode = false;
                          selectedChapter = null;
                        });
                        await loadInitialData();
                      },
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _buildBody(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return ErrorState(error: error!, onRetry: loadInitialData);
    }

    if (selectedChapter != null) {
      return ChapterDetail(chapter: selectedChapter!, onBack: closeChapter);
    }

    return CourseDashboard(
      courses: courses,
      chapters: chapters,
      selectedCourse: selectedCourse,
      onOpenChapter: openChapter,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onLogin});

  final HouvastApi api;
  final ValueChanged<AppSession> onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF24302F),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'H',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Houvast',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Log in of ga tijdelijk verder als gast',
                              style: TextStyle(color: Color(0xFF66716C)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Naam voor op het groepsbord',
                      hintText: 'Bijv. Ruard',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: loading ? null : _continueAsGuest,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Verder als gast'),
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Admin-wachtwoord',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _loginAdmin(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: loading ? null : _loginAdmin,
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Inloggen als admin'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFF9E3E2F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    await _run(() => widget.api.loginGuest(name: nameController.text));
  }

  Future<void> _loginAdmin() async {
    await _run(() => widget.api.loginAdmin(passwordController.text));
  }

  Future<void> _run(Future<AppSession> Function() action) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      widget.onLogin(await action());
    } catch (exception) {
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }
}

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final api = HouvastApi();
  final passwordController = TextEditingController();
  String? error;

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin openen'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Wachtwoord'),
              onSubmitted: (_) => _login(),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Color(0xFF9E3E2F))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(onPressed: _login, child: const Text('Open admin')),
      ],
    );
  }

  Future<void> _login() async {
    try {
      Navigator.of(context).pop(await api.loginAdmin(passwordController.text));
    } catch (exception) {
      setState(() => error = exception.toString());
    }
  }
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.session,
    required this.onAdmin,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onAdmin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3DED2))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF24302F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'H',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Houvast',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                'Samen God leren kennen',
                style: TextStyle(fontSize: 13, color: Color(0xFF66716C)),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0ECE2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${session.username} (${session.isAdmin ? 'admin' : 'gast'})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onAdmin,
            icon: const Icon(Icons.construction),
            label: const Text('Admin'),
          ),
          IconButton(
            tooltip: 'Uitloggen',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
          const ApiStatusPill(),
        ],
      ),
    );
  }
}

class ApiStatusPill extends StatelessWidget {
  const ApiStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F1EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'API: 127.0.0.1:8000',
        style: TextStyle(
          color: Color(0xFF365847),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class CourseDashboard extends StatelessWidget {
  const CourseDashboard({
    super.key,
    required this.courses,
    required this.chapters,
    required this.selectedCourse,
    required this.onOpenChapter,
  });

  final List<dynamic> courses;
  final List<dynamic> chapters;
  final Map<String, dynamic>? selectedCourse;
  final ValueChanged<String> onOpenChapter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 840;
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HeroPanel(course: selectedCourse, chapters: chapters),
                        const SizedBox(height: 18),
                        AdminPreviewPanel(courseCount: courses.length),
                      ],
                    );
                  }

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: HeroPanel(
                            course: selectedCourse,
                            chapters: chapters,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 2,
                          child: AdminPreviewPanel(courseCount: courses.length),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(
                'Hoofdstukken',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: chapters
                    .cast<Map<String, dynamic>>()
                    .map(
                      (chapter) => ChapterCard(
                        chapter: chapter,
                        onOpen: () => onOpenChapter(chapter['id'] as String),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.course, required this.chapters});

  final Map<String, dynamic>? course;
  final List<dynamic> chapters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF24302F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leerling-app',
            style: TextStyle(
              color: Color(0xFFBFD5C7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            course?['title'] as String? ?? 'Cursus laden...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            course?['description'] as String? ?? '',
            style: const TextStyle(
              color: Color(0xFFEAF0EA),
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          ProgressStrip(chapters: chapters),
        ],
      ),
    );
  }
}

class ProgressStrip extends StatelessWidget {
  const ProgressStrip({super.key, required this.chapters});

  final List<dynamic> chapters;

  @override
  Widget build(BuildContext context) {
    final chapterMaps = chapters.cast<Map<String, dynamic>>();
    final blockCount = chapterMaps.fold<int>(
      0,
      (sum, chapter) => sum + (chapter['block_count'] as int? ?? 0),
    );
    final xpTotal = chapterMaps.fold<int>(
      0,
      (sum, chapter) => sum + (chapter['xp'] as int? ?? 0),
    );

    return Row(
      children: [
        _metric('${chapters.length}', 'hoofdstukken'),
        _metric('$blockCount', 'blocks'),
        _metric('$xpTotal', 'XP'),
      ],
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF31413F),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFBFD5C7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPreviewPanel extends StatelessWidget {
  const AdminPreviewPanel({super.key, required this.courseCount});

  final int courseCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin-CMS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Deze frontend leest nu seed-content uit de backend. Straks beheert de catecheet dezelfde structuur via het CMS.',
            ),
            const SizedBox(height: 18),
            _check('Content komt uit API'),
            _check('Hoofdstukken niet hardcoded'),
            _check('Blocks generiek renderbaar'),
            _check('$courseCount cursus actief'),
          ],
        ),
      ),
    );
  }

  Widget _check(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF5F7A6A), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class ChapterCard extends StatelessWidget {
  const ChapterCard({super.key, required this.chapter, required this.onOpen});

  final Map<String, dynamic> chapter;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hoofdstuk ${chapter['sort_order']}',
                        style: const TextStyle(
                          color: Color(0xFF66716C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF5F7A6A)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  chapter['title'] as String,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(chapter['subtitle'] as String),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _pill('${chapter['block_count']} blocks'),
                    const SizedBox(width: 8),
                    _pill('${chapter['xp']} XP'),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.play_arrow,
                      size: 20,
                      color: Color(0xFF24302F),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Open les',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class ChapterDetail extends StatefulWidget {
  const ChapterDetail({super.key, required this.chapter, required this.onBack});

  final Map<String, dynamic> chapter;
  final VoidCallback onBack;

  @override
  State<ChapterDetail> createState() => _ChapterDetailState();
}

class _ChapterDetailState extends State<ChapterDetail> {
  late List<GlobalKey> blockKeys;

  @override
  void initState() {
    super.initState();
    final blocks = (widget.chapter['blocks'] as List<dynamic>? ?? const []);
    blockKeys = List.generate(blocks.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant ChapterDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final blocks = (widget.chapter['blocks'] as List<dynamic>? ?? const []);
    if (oldWidget.chapter['id'] != widget.chapter['id'] ||
        blockKeys.length != blocks.length) {
      blockKeys = List.generate(blocks.length, (_) => GlobalKey());
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = (widget.chapter['blocks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final chapterId = widget.chapter['id'] as String? ?? '';
    final introEntries = blocks
        .asMap()
        .entries
        .where((entry) => _isFixedIntroBlock(entry.value))
        .toList();
    final routeEntries = blocks
        .asMap()
        .entries
        .where((entry) => !_isFixedIntroBlock(entry.value))
        .toList();

    return AnimatedBuilder(
      animation: LessonProgress.instance,
      builder: (context, _) {
        final completedRouteCount = LessonProgress.instance.completedCount(
          chapterId,
          routeEntries,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Terug naar overzicht'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.chapter['title'] as String,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.chapter['subtitle'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF66716C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...introEntries.map((entry) {
                    final index = entry.key;
                    final block = entry.value;
                    return BlockPreview(
                      key: blockKeys[index],
                      block: block,
                      blockNumber: null,
                      totalBlocks: null,
                      blockContext: BlockContext(
                        courseId: widget.chapter['course_id'] as String? ?? '',
                        chapterId: chapterId,
                        blockId: block['id'] as String? ?? '',
                        blockType: block['type'] as String? ?? '',
                      ),
                      isComplete: LessonProgress.instance.isComplete(
                        chapterId,
                        block['id'] as String? ?? '',
                      ),
                    );
                  }),
                  if (routeEntries.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    LessonRoutePanel(
                      entries: routeEntries,
                      chapterId: chapterId,
                      completedCount: completedRouteCount,
                      onJump: (originalIndex) {
                        final context = blockKeys[originalIndex].currentContext;
                        if (context == null) return;
                        Scrollable.ensureVisible(
                          context,
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          alignment: 0.08,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  ...routeEntries.asMap().entries.map((routeEntry) {
                    final routeIndex = routeEntry.key;
                    final originalIndex = routeEntry.value.key;
                    final block = routeEntry.value.value;
                    return BlockPreview(
                      key: blockKeys[originalIndex],
                      block: block,
                      blockNumber: routeIndex + 1,
                      totalBlocks: routeEntries.length,
                      blockContext: BlockContext(
                        courseId: widget.chapter['course_id'] as String? ?? '',
                        chapterId: chapterId,
                        blockId: block['id'] as String? ?? '',
                        blockType: block['type'] as String? ?? '',
                      ),
                      isComplete: LessonProgress.instance.isComplete(
                        chapterId,
                        block['id'] as String? ?? '',
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isFixedIntroBlock(Map<String, dynamic> block) {
    return block['type'] == 'hero' || block['type'] == 'reading_plan';
  }
}

class LessonRoutePanel extends StatelessWidget {
  const LessonRoutePanel({
    super.key,
    required this.entries,
    required this.chapterId,
    required this.completedCount,
    required this.onJump,
  });

  final List<MapEntry<int, Map<String, dynamic>>> entries;
  final String chapterId;
  final int completedCount;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3DED2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xFF5F7A6A)),
              const SizedBox(width: 8),
              Text('Lesroute', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '$completedCount van ${entries.length} klaar',
                style: const TextStyle(
                  color: Color(0xFF66716C),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries.asMap().entries.map((routeEntry) {
              final routeIndex = routeEntry.key;
              final originalIndex = routeEntry.value.key;
              final block = routeEntry.value.value;
              final isDone = LessonProgress.instance.isComplete(
                chapterId,
                block['id'] as String? ?? '',
              );
              return ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: isDone
                      ? const Color(0xFF247A4D)
                      : const Color(0xFFE9F1EC),
                  child: isDone
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : Text(
                          '${routeIndex + 1}',
                          style: const TextStyle(
                            color: Color(0xFF24302F),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                label: Text(block['title'] as String? ?? 'Onderdeel'),
                onPressed: () => onJump(originalIndex),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class BlockPreview extends StatelessWidget {
  const BlockPreview({
    super.key,
    required this.block,
    required this.blockContext,
    this.blockNumber,
    this.totalBlocks,
    this.isComplete = false,
  });

  final Map<String, dynamic> block;
  final BlockContext blockContext;
  final int? blockNumber;
  final int? totalBlocks;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final content = block['content'] as Map<String, dynamic>;
    final isReadingPlan = block['type'] == 'reading_plan';
    final isIntro = block['type'] == 'hero';
    final showXp = !isIntro;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: isReadingPlan ? const Color(0xFFFFFBF0) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isReadingPlan
              ? const Color(0xFFD8C98B)
              : isComplete
              ? const Color(0xFF247A4D)
              : const Color(0xFFE3DED2),
          width: isReadingPlan || isComplete ? 1.8 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForType(block['type'] as String),
                  color: const Color(0xFF5F7A6A),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    block['title'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (showXp) ...[
                  Text(
                    '${block['xp']} XP',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                ],
                if (blockNumber != null && totalBlocks != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0ECE2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Stap $blockNumber/$totalBlocks',
                      style: const TextStyle(
                        color: Color(0xFF66716C),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                if (isComplete) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF247A4D),
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            ..._contentWidgets(context, content),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'hero' => Icons.auto_awesome,
      'bible' => Icons.menu_book,
      'reading_plan' => Icons.calendar_month,
      'reflection' => Icons.edit_note,
      'deep_dive' => Icons.travel_explore,
      'group_discussion' => Icons.forum,
      'statement_response' => Icons.style,
      'challenge' => Icons.flag,
      'promise' => Icons.volunteer_activism,
      'sorting' => Icons.swap_vert,
      'distribution' => Icons.pie_chart,
      'multiple_choice' => Icons.checklist,
      'youtube' => Icons.smart_display,
      'media_player' => Icons.play_circle,
      'quote' => Icons.format_quote,
      'upload' => Icons.upload_file,
      'gallery' => Icons.photo_library,
      'slider' => Icons.tune,
      _ => Icons.widgets,
    };
  }

  List<Widget> _contentWidgets(
    BuildContext context,
    Map<String, dynamic> content,
  ) {
    if (block['type'] == 'distribution') {
      return [DistributionBlock(content: content, blockContext: blockContext)];
    }

    if (block['type'] == 'bible') {
      return [BibleBlock(content: content, blockContext: blockContext)];
    }

    if (block['type'] == 'reading_plan') {
      return [ReadingPlanBlock(content: content, blockContext: blockContext)];
    }

    if (block['type'] == 'deep_dive') {
      return [DeepDiveBlock(content: content, blockContext: blockContext)];
    }

    if (block['type'] == 'slider') {
      return [SliderBlock(content: content, blockContext: blockContext)];
    }

    if (block['type'] == 'multiple_choice') {
      return [
        MultipleChoiceBlock(content: content, blockContext: blockContext),
      ];
    }

    if (block['type'] == 'statement_response') {
      return [
        StatementResponseBlock(content: content, blockContext: blockContext),
      ];
    }

    if (block['type'] == 'challenge') {
      return [ChallengeBlock(content: content, blockContext: blockContext)];
    }

    if (block['type'] == 'promise') {
      return [PromiseBlock(content: content, blockContext: blockContext)];
    }

    if (block['type'] == 'sorting') {
      return [SortingBlock(content: content, blockContext: blockContext)];
    }

    if (['youtube', 'media_player', 'audio'].contains(block['type'])) {
      return [MediaBlock(content: content, type: block['type'] as String)];
    }

    if (block['type'] == 'quote') {
      return [QuoteBlock(content: content)];
    }

    if (block['type'] == 'gallery' || block['type'] == 'upload') {
      return [
        MediaCanvasBlock(
          content: content,
          type: block['type'] as String,
          blockContext: blockContext,
        ),
      ];
    }

    final widgets = <Widget>[];

    void addText(String? text, {bool muted = false}) {
      if (text == null || text.trim().isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: TextStyle(
              color: muted ? const Color(0xFF66716C) : const Color(0xFF24302F),
            ),
          ),
        ),
      );
    }

    addText(content['subtitle'] as String?, muted: true);
    addText(content['body'] as String?);
    addText(content['summary'] as String?);
    addText(content['intro'] as String?);
    addText(content['case_text'] as String?);
    addText(content['prompt'] as String?);
    addText(content['question'] as String?);

    if (content['callout'] is String) {
      widgets.add(_callout(content['callout'] as String));
    }

    if (content['reference'] is String) {
      widgets.add(_tagRow(['Bijbelgedeelte: ${content['reference']}']));
    }

    if (content['references'] is List) {
      widgets.add(_sectionTitle(context, 'Teksten'));
      widgets.add(
        _tagRow(
          (content['references'] as List).map((item) => '$item').toList(),
        ),
      );
    }

    if (content['items'] is List) {
      widgets.add(_sectionTitle(context, 'Onderdelen'));
      widgets.add(
        _bulletList((content['items'] as List).map((item) => '$item').toList()),
      );
    }

    if (content['examples'] is List) {
      widgets.add(_sectionTitle(context, 'Voorbeelden'));
      widgets.add(
        _bulletList(
          (content['examples'] as List).map((item) => '$item').toList(),
        ),
      );
    }

    if (content['questions'] is List) {
      widgets.add(_sectionTitle(context, 'Vragen'));
      widgets.add(
        QuestionFlow(
          questions: (content['questions'] as List)
              .map((item) => '$item')
              .toList(),
          blockContext: blockContext,
        ),
      );
    }

    if (content['discussion_questions'] is List) {
      widgets.add(_sectionTitle(context, 'Gespreksvragen'));
      widgets.add(
        QuestionFlow(
          questions: (content['discussion_questions'] as List)
              .map((item) => '$item')
              .toList(),
          blockContext: blockContext,
        ),
      );
    }

    final url = content['url'] as String? ?? '';
    if (url.isNotEmpty) {
      final linkLabel =
          content['link_label'] as String? ??
          content['button_label'] as String?;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: OutlinedButton.icon(
            onPressed: () =>
                launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
            icon: const Icon(Icons.open_in_new),
            label: Text(
              linkLabel?.trim().isNotEmpty == true
                  ? linkLabel!.trim()
                  : 'Open link',
            ),
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(const Text('Dit block is geladen uit de database.'));
    }

    return widgets;
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _callout(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE2),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF5F7A6A), width: 4),
        ),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _tagRow(List<String> tags) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags
            .map(
              (tag) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F1EC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _bulletList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('- '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class DeepDiveBlock extends StatelessWidget {
  const DeepDiveBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  Widget build(BuildContext context) {
    final sections = (content['sections'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final summary = content['summary'] as String?;
    final callout = content['callout'] as String?;
    final references = (content['references'] as List<dynamic>? ?? const [])
        .map((item) => '$item')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null) ...[Text(summary), const SizedBox(height: 12)],
        if (callout != null) ...[_callout(callout), const SizedBox(height: 12)],
        if (sections.isNotEmpty) ...[
          Text('Verdiepingen', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth < 620
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: sections
                    .asMap()
                    .entries
                    .map(
                      (entry) => SizedBox(
                        width: tileWidth,
                        child: DeepDiveTile(
                          section: entry.value,
                          blockContext: blockContext,
                          sectionIndex: entry.key,
                          totalSections: sections.length,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
        if (references.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Bijbehorende teksten',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: references
                .map(
                  (reference) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F1EC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      reference,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _callout(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE2),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF5F7A6A), width: 4),
        ),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class SliderBlock extends StatefulWidget {
  const SliderBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  State<SliderBlock> createState() => _SliderBlockState();
}

class _SliderBlockState extends State<SliderBlock> {
  late double value;

  @override
  void initState() {
    super.initState();
    value = (widget.content['default'] as int? ?? 50).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final min = (widget.content['min'] as int? ?? 0).toDouble();
    final max = (widget.content['max'] as int? ?? 100).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.content['prompt'] as String? ?? ''),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(widget.content['min_label'] as String? ?? '$min'),
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: (max - min).round(),
                label: value.round().toString(),
                onChanged: (next) => setState(() => value = next),
                onChangeEnd: (next) => ActivityTracker(widget.blockContext)
                    .track('slider_changed', {
                      'prompt': widget.content['prompt'] as String? ?? '',
                      'value': next.round(),
                    }),
              ),
            ),
            Text(widget.content['max_label'] as String? ?? '$max'),
          ],
        ),
        Text(
          'Jouw keuze: ${value.round()}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class MultipleChoiceBlock extends StatefulWidget {
  const MultipleChoiceBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  State<MultipleChoiceBlock> createState() => _MultipleChoiceBlockState();
}

class _MultipleChoiceBlockState extends State<MultipleChoiceBlock> {
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    final options = (widget.content['options'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final selected = options
        .where((option) => option['id'] == selectedId)
        .firstOrNull;
    final isCorrect = selected?['is_correct'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.content['question'] as String? ?? ''),
        const SizedBox(height: 10),
        ...options.map((option) {
          final id = option['id'] as String;
          final selected = selectedId == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() => selectedId = id);
                ActivityTracker(
                  widget.blockContext,
                ).track('multiple_choice_selected', {
                  'question': widget.content['question'] as String? ?? '',
                  'option_id': id,
                  'option_text': option['text'] as String? ?? '',
                  'is_correct': option['is_correct'] == true,
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE9F1EC) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF5F7A6A)
                        : const Color(0xFFE3DED2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: const Color(0xFF5F7A6A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(option['text'] as String? ?? '')),
                  ],
                ),
              ),
            ),
          );
        }),
        if (selected != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCorrect
                  ? const Color(0xFFE9F1EC)
                  : const Color(0xFFFFF1D6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${isCorrect ? 'Goed' : 'Nog eens kijken'}${(widget.content['explanation'] as String? ?? '').isEmpty ? '' : ': ${widget.content['explanation']}'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class StatementResponseBlock extends StatefulWidget {
  const StatementResponseBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  State<StatementResponseBlock> createState() => _StatementResponseBlockState();
}

class _StatementResponseBlockState extends State<StatementResponseBlock> {
  final pageController = PageController(viewportFraction: 0.86);
  final answerController = TextEditingController();
  int selectedIndex = 0;
  String lastTrackedAnswer = '';

  @override
  void initState() {
    super.initState();
    answerController.addListener(_onAnswerChanged);
  }

  @override
  void dispose() {
    pageController.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intro = widget.content['intro'] as String? ?? '';
    final prompt =
        widget.content['prompt'] as String? ?? 'Kies een uitspraak en reageer.';
    final statements = _statements();
    if (statements.isEmpty) return const Text('Geen uitspraken ingesteld.');

    final selectedStatement =
        statements[selectedIndex.clamp(0, statements.length - 1)];
    final prefix = '$selectedStatement: ';
    final answer = answerController.text.trim();
    final hasAnswer = answer.length > prefix.length;
    final entries = hasAnswer
        ? [
            {
              'name': AppSession.current?.username ?? 'Gast',
              'label': 'Uitspraak ${selectedIndex + 1}',
              'answer': answer,
            },
          ]
        : <Map<String, String>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intro.isNotEmpty) ...[Text(intro), const SizedBox(height: 10)],
        Text(prompt, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: pageController,
            itemCount: statements.length,
            onPageChanged: (index) => setState(() => selectedIndex = index),
            itemBuilder: (context, index) {
              final active = index == selectedIndex;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.fromLTRB(
                  0,
                  active ? 0 : 12,
                  12,
                  active ? 0 : 12,
                ),
                child: _StatementCard(
                  number: index + 1,
                  statement: statements[index],
                  active: active,
                  onTap: () => selectStatement(index),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < statements.length; i++)
                Container(
                  width: i == selectedIndex ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? const Color(0xFF247A4D)
                        : const Color(0xFFD7D8D0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: answerController,
          minLines: 3,
          maxLines: null,
          decoration: InputDecoration(
            labelText: 'Typ je reactie',
            hintText: '$selectedStatement: vul aan...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => selectStatement(selectedIndex),
              icon: const Icon(Icons.edit),
              label: const Text('Gebruik deze uitspraak'),
            ),
            const Spacer(),
            Text(
              hasAnswer
                  ? 'Verschijnt op groepsbord'
                  : 'Vul aan na de dubbele punt.',
              style: const TextStyle(
                color: Color(0xFF5F7A6A),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        BlackboardBubbles(entries: entries, blockContext: widget.blockContext),
      ],
    );
  }

  List<String> _statements() {
    return (widget.content['statements'] as List<dynamic>? ?? const [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  void _onAnswerChanged() {
    setState(() {});
    final statements = _statements();
    if (statements.isEmpty) return;
    final selectedStatement =
        statements[selectedIndex.clamp(0, statements.length - 1)];
    final prefix = '$selectedStatement: ';
    final answer = answerController.text.trim();
    if (answer.length <= prefix.length || answer == lastTrackedAnswer) return;
    Future<void>.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted ||
          answerController.text.trim() != answer ||
          answer == lastTrackedAnswer) {
        return;
      }
      lastTrackedAnswer = answer;
      await ActivityTracker(
        widget.blockContext,
      ).track('statement_response_answered', {
        'statement_index': selectedIndex + 1,
        'statement': selectedStatement,
        'answer': answer,
      });
    });
  }

  void selectStatement(int index) {
    final statements = _statements();
    if (index < 0 || index >= statements.length) return;
    final statement = statements[index];
    setState(() {
      selectedIndex = index;
      answerController.text = '$statement: ';
      answerController.selection = TextSelection.collapsed(
        offset: answerController.text.length,
      );
    });
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({
    required this.number,
    required this.statement,
    required this.active,
    required this.onTap,
  });

  final int number;
  final String statement;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF20312E) : const Color(0xFFF8F6EF),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? const Color(0xFF20312E) : const Color(0xFFE3DED2),
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFFFE7A8)
                          : const Color(0xFFE9F1EC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF20312E),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.swipe,
                    color: active
                        ? const Color(0xFFFFE7A8)
                        : const Color(0xFF5F7A6A),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Text(
                  statement,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF24302F),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    height: 1.18,
                  ),
                ),
              ),
              Text(
                'Tik om hierop te reageren',
                style: TextStyle(
                  color: active
                      ? const Color(0xFFCFE0D6)
                      : const Color(0xFF66716C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PromiseBlock extends StatelessWidget {
  const PromiseBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  Widget build(BuildContext context) {
    final prompts = (content['prompts'] as List<dynamic>? ?? const [])
        .map((item) => '$item')
        .toList();
    final minCharacters = content['min_characters'] as int? ?? 25;
    final intro =
        content['intro'] as String? ??
        'Schrijf per vraag een echte zin. Je antwoord verschijnt op het groepsbord.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(intro),
        const SizedBox(height: 12),
        QuestionFlow(
          questions: prompts,
          minCharacters: minCharacters,
          labelPrefix: 'Meenemen',
          hintText: 'Schrijf een zin...',
          blockContext: blockContext,
        ),
      ],
    );
  }
}

class ChallengeBlock extends StatefulWidget {
  const ChallengeBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  State<ChallengeBlock> createState() => _ChallengeBlockState();
}

class _ChallengeBlockState extends State<ChallengeBlock> {
  final nameController = TextEditingController();
  final linkController = TextEditingController();
  final noteController = TextEditingController();
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    nameController.addListener(_refresh);
    linkController.addListener(_refresh);
    noteController.addListener(_refresh);
  }

  @override
  void dispose() {
    nameController.dispose();
    linkController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.content['prompt'] as String? ?? '';
    final examples = (widget.content['examples'] as List<dynamic>? ?? const [])
        .map((item) => '$item')
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final minCharacters = widget.content['min_characters'] as int? ?? 20;
    final entries = submitted
        ? [
            {
              'name': AppSession.current?.username ?? 'Gast',
              'label': 'Challenge',
              'answer': _boardText(),
            },
          ]
        : <Map<String, String>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prompt.isNotEmpty) ...[Text(prompt), const SizedBox(height: 12)],
        if (examples.isNotEmpty) ...[
          Text('Ideeën', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: examples
                .map(
                  (example) => ActionChip(
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        example,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onPressed: () {
                      if (noteController.text.trim().isEmpty) {
                        noteController.text = example;
                      } else {
                        noteController.text =
                            '${noteController.text.trim()}\n$example';
                      }
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3DED2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jouw challenge',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Naam van je actie',
                  hintText: 'Bijv. Minder kopen, afval opruimen, dankgebed',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: linkController,
                decoration: InputDecoration(
                  labelText: 'Webpagina, video of bewijslink',
                  hintText: 'https://...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                minLines: 3,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: 'Wat ga je doen of wat heb je gedaan?',
                  hintText:
                      'Schrijf concreet genoeg dat iemand anders begrijpt wat je bedoelt.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _canSubmit(minCharacters)
                    ? 'Klaar om te delen op het groepsbord.'
                    : 'Vul minimaal een naam en ongeveer $minCharacters tekens toelichting in.',
                style: TextStyle(
                  color: _canSubmit(minCharacters)
                      ? const Color(0xFF247A4D)
                      : const Color(0xFF66716C),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _canSubmit(minCharacters) ? _submit : null,
                  icon: const Icon(Icons.flag),
                  label: const Text('Deel challenge'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BlackboardBubbles(entries: entries, blockContext: widget.blockContext),
      ],
    );
  }

  bool _canSubmit(int minCharacters) {
    return nameController.text.trim().isNotEmpty &&
        noteController.text.trim().length >= minCharacters;
  }

  String _boardText() {
    final name = nameController.text.trim();
    final note = noteController.text.trim();
    final link = linkController.text.trim();
    return link.isEmpty ? '$name: $note' : '$name: $note\n$link';
  }

  void _refresh() {
    if (mounted) setState(() => submitted = false);
  }

  void _submit() {
    setState(() => submitted = true);
    ActivityTracker(widget.blockContext).track('challenge_submitted', {
      'name': nameController.text.trim(),
      'link': linkController.text.trim(),
      'note': noteController.text.trim(),
      'completed': true,
    });
  }
}

class SortingBlock extends StatefulWidget {
  const SortingBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  State<SortingBlock> createState() => _SortingBlockState();
}

class _SortingBlockState extends State<SortingBlock> {
  late final List<Map<String, dynamic>> items;
  late final List<String> categories;
  late List<Map<String, dynamic>> available;
  late Map<String, List<Map<String, dynamic>>> placed;

  @override
  void initState() {
    super.initState();
    items = (widget.content['items'] as List<dynamic>? ?? const []).map((item) {
      if (item is Map<String, dynamic>) return item;
      return {'text': '$item', 'category': ''};
    }).toList();
    categories = (widget.content['categories'] as List<dynamic>? ?? const [])
        .map((item) => '$item')
        .toList();
    available = List<Map<String, dynamic>>.from(items);
    placed = {
      for (final category in categories) category: <Map<String, dynamic>>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.content['prompt'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prompt.isNotEmpty) ...[Text(prompt), const SizedBox(height: 14)],
        Text('Te sorteren', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F3EA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3DED2)),
          ),
          child: available.isEmpty
              ? const Text(
                  'Alles is geplaatst.',
                  style: TextStyle(color: Color(0xFF66716C)),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: available.map(_draggableChip).toList(),
                ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 720
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map(
                    (category) => SizedBox(
                      width: width,
                      child: _categoryDropZone(context, category),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _categoryDropZone(BuildContext context, String category) {
    final categoryItems = placed[category] ?? <Map<String, dynamic>>[];
    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) {
        setState(() {
          _removeEverywhere(details.data);
          placed
              .putIfAbsent(category, () => <Map<String, dynamic>>[])
              .add(details.data);
        });
        ActivityTracker(widget.blockContext).track('sorting_item_placed', {
          'item': _itemText(details.data),
          'category': category,
          'completed': available.isEmpty,
          'placed': placed.map(
            (key, value) => MapEntry(key, value.map(_itemText).toList()),
          ),
        });
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE9F1EC) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? const Color(0xFF5F7A6A) : const Color(0xFFE3DED2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (categoryItems.isEmpty)
                const Text(
                  'Sleep hierheen',
                  style: TextStyle(color: Color(0xFF66716C)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryItems.map(_draggableChip).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _draggableChip(Map<String, dynamic> item) {
    return Draggable<Map<String, dynamic>>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: _chip(_itemText(item), elevated: true),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _chip(_itemText(item))),
      child: _chip(_itemText(item)),
    );
  }

  Widget _chip(String text, {bool elevated = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: elevated ? const Color(0xFF20312E) : const Color(0xFFE9F1EC),
        borderRadius: BorderRadius.circular(999),
        boxShadow: elevated
            ? const [BoxShadow(color: Color(0x33000000), blurRadius: 8)]
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: elevated ? Colors.white : const Color(0xFF24302F),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _removeEverywhere(Map<String, dynamic> item) {
    available.removeWhere(
      (candidate) => _itemText(candidate) == _itemText(item),
    );
    for (final list in placed.values) {
      list.removeWhere((candidate) => _itemText(candidate) == _itemText(item));
    }
  }

  String _itemText(Map<String, dynamic> item) =>
      '${item['text'] ?? item['label'] ?? ''}';
}

class MediaBlock extends StatelessWidget {
  const MediaBlock({super.key, required this.content, required this.type});

  final Map<String, dynamic> content;
  final String type;

  @override
  Widget build(BuildContext context) {
    final url = content['url'] as String? ?? '';
    final intro = content['intro'] as String? ?? '';
    final isYoutube = type == 'youtube' && url.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intro.isNotEmpty) ...[Text(intro), const SizedBox(height: 12)],
        if (isYoutube) ...[
          buildYoutubeEmbed(url),
          const SizedBox(height: 10),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF20312E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(
                  type == 'audio' ? Icons.audiotrack : Icons.smart_display,
                  color: Colors.white,
                  size: 42,
                ),
                const SizedBox(height: 10),
                Text(
                  url.isEmpty ? 'Nog geen media URL ingesteld' : url,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (url.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in nieuw tabblad'),
            ),
          ),
      ],
    );
  }
}

class QuoteBlock extends StatelessWidget {
  const QuoteBlock({super.key, required this.content});

  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE2),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF5F7A6A), width: 5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content['quote'] as String? ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if ((content['source'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '- ${content['source']}',
              style: const TextStyle(color: Color(0xFF66716C)),
            ),
          ],
        ],
      ),
    );
  }
}

class MediaCanvasBlock extends StatefulWidget {
  const MediaCanvasBlock({
    super.key,
    required this.content,
    required this.type,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final String type;
  final BlockContext blockContext;

  @override
  State<MediaCanvasBlock> createState() => _MediaCanvasBlockState();
}

class _MediaCanvasBlockState extends State<MediaCanvasBlock> {
  static final Map<String, List<CanvasMediaItem>> _boards = {};

  final linkController = TextEditingController();
  final noteController = TextEditingController();
  PlatformFile? pickedFile;

  String get boardKey =>
      widget.content['id'] as String? ??
      widget.content['prompt'] as String? ??
      identityHashCode(widget.content).toString();

  List<CanvasMediaItem> get items =>
      _boards.putIfAbsent(boardKey, () => <CanvasMediaItem>[]);

  @override
  void initState() {
    super.initState();
    linkController.addListener(refreshSubmitState);
    noteController.addListener(refreshSubmitState);
  }

  @override
  void dispose() {
    linkController.removeListener(refreshSubmitState);
    noteController.removeListener(refreshSubmitState);
    linkController.dispose();
    noteController.dispose();
    super.dispose();
  }

  void refreshSubmitState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.content['prompt'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prompt.isNotEmpty) ...[Text(prompt), const SizedBox(height: 14)],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3DED2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deel iets met de klas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: linkController,
                      decoration: InputDecoration(
                        labelText: 'Link naar foto/video',
                        hintText: 'https://...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      pickedFile == null
                          ? 'Upload foto/video'
                          : pickedFile!.name,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText:
                      'Wat zie je hierin van Gods grootheid, zorg of creativiteit?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: canSubmit ? submit : null,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Plaats op klasbord'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        MediaCanvasBoard(items: items),
      ],
    );
  }

  bool get canSubmit =>
      pickedFile != null ||
      linkController.text.trim().isNotEmpty ||
      noteController.text.trim().isNotEmpty;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => pickedFile = result.files.single);
  }

  void submit() {
    final link = linkController.text.trim();
    final note = noteController.text.trim();
    if (link.isEmpty && pickedFile == null && note.isEmpty) return;
    final kind = mediaKind(link: link, fileName: pickedFile?.name);
    final fileName = pickedFile?.name;

    setState(() {
      items.add(
        CanvasMediaItem(
          name: AppSession.current?.username ?? 'Gast',
          note: note,
          link: link,
          fileName: fileName,
          bytes: pickedFile?.bytes,
          kind: kind,
        ),
      );
      linkController.clear();
      noteController.clear();
      pickedFile = null;
    });
    ActivityTracker(widget.blockContext).track('media_canvas_posted', {
      'kind': kind,
      'link': link,
      'file_name': fileName ?? '',
      'note': note,
    });
  }

  String mediaKind({required String link, String? fileName}) {
    final value = (fileName ?? link).toLowerCase();
    if (value.endsWith('.mp4') ||
        value.endsWith('.mov') ||
        value.endsWith('.webm') ||
        value.contains('youtube.com') ||
        value.contains('youtu.be') ||
        value.contains('vimeo.com')) {
      return 'video';
    }
    if (value.endsWith('.jpg') ||
        value.endsWith('.jpeg') ||
        value.endsWith('.png') ||
        value.endsWith('.gif') ||
        value.endsWith('.webp')) {
      return 'image';
    }
    return link.isNotEmpty ? 'link' : 'image';
  }
}

class CanvasMediaItem {
  const CanvasMediaItem({
    required this.name,
    required this.note,
    required this.kind,
    this.link = '',
    this.fileName,
    this.bytes,
  });

  final String name;
  final String note;
  final String kind;
  final String link;
  final String? fileName;
  final Uint8List? bytes;
}

class MediaCanvasBoard extends StatelessWidget {
  const MediaCanvasBoard({super.key, required this.items});

  final List<CanvasMediaItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF20312E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Klasbord',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Foto’s, video’s en links verschijnen hier zodra iemand iets deelt.',
            style: TextStyle(color: Color(0xFFCFE0D6), fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF2B423D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF49665E)),
              ),
              child: const Text(
                'Nog niets gedeeld.',
                style: TextStyle(color: Color(0xFFCFE0D6)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 680
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: width,
                          child: _mediaCard(context, item),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _mediaCard(BuildContext context, CanvasMediaItem item) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _preview(item),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Color(0xFF5F7A6A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _kindBadge(item.kind),
                  ],
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(item.note),
                ],
                if (item.link.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(item.link),
                      webOnlyWindowName: '_blank',
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open link'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(CanvasMediaItem item) {
    if (item.bytes != null && item.kind == 'image') {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.memory(item.bytes!, fit: BoxFit.cover),
      );
    }

    final icon = item.kind == 'video'
        ? Icons.play_circle_fill
        : item.kind == 'image'
        ? Icons.image
        : Icons.link;
    final title = item.fileName ?? (item.link.isEmpty ? 'Media' : item.link);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: const Color(0xFFE9F1EC),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF365847), size: 44),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindBadge(String kind) {
    final label = switch (kind) {
      'video' => 'Video',
      'image' => 'Foto',
      _ => 'Link',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class DeepDiveTile extends StatefulWidget {
  const DeepDiveTile({
    super.key,
    required this.section,
    required this.blockContext,
    required this.sectionIndex,
    required this.totalSections,
  });

  final Map<String, dynamic> section;
  final BlockContext blockContext;
  final int sectionIndex;
  final int totalSections;

  @override
  State<DeepDiveTile> createState() => _DeepDiveTileState();
}

class _DeepDiveTileState extends State<DeepDiveTile> {
  static final Map<String, Set<int>> _readSectionsByBlock = {};

  bool read = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.section['title'] as String? ?? 'Verdieping';
    final body = widget.section['body'] as String? ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: read ? const Color(0xFF247A4D) : const Color(0xFFE3DED2),
          width: read ? 2.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openDeepDive(context, title, body),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F1EC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.travel_explore,
                      size: 19,
                      color: Color(0xFF365847),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(
                    read ? Icons.check_circle : Icons.chevron_right,
                    color: read
                        ? const Color(0xFF247A4D)
                        : const Color(0xFF5F7A6A),
                  ),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF66716C)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDeepDive(
    BuildContext context,
    String title,
    String body,
  ) async {
    final openedAt = DateTime.now();
    await showDialog<void>(
      context: context,
      builder: (_) => DeepDiveDialog(title: title, body: body),
    );
    final secondsOpen = DateTime.now().difference(openedAt).inSeconds;
    if (secondsOpen < 5 || read) return;

    setState(() => read = true);
    final readSections = _readSectionsByBlock.putIfAbsent(
      '${widget.blockContext.chapterId}:${widget.blockContext.blockId}',
      () => <int>{},
    );
    readSections.add(widget.sectionIndex);
    await ActivityTracker(widget.blockContext).track('deep_dive_read', {
      'section_title': title,
      'seconds_open': secondsOpen,
      'read_sections': readSections.length,
      'total_sections': widget.totalSections,
      'completed': readSections.length >= widget.totalSections,
    });
  }
}

class DeepDiveDialog extends StatelessWidget {
  const DeepDiveDialog({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(body),
            ],
          ),
        ),
      ),
    );
  }
}

class DistributionBlock extends StatefulWidget {
  const DistributionBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  State<DistributionBlock> createState() => _DistributionBlockState();
}

class ReadingPlanBlock extends StatefulWidget {
  const ReadingPlanBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  State<ReadingPlanBlock> createState() => _ReadingPlanBlockState();
}

class _ReadingPlanBlockState extends State<ReadingPlanBlock> {
  static final Map<String, Set<int>> _completedByPlan = {};

  String get planKey =>
      widget.content['id'] as String? ??
      (widget.content['title'] as String? ??
              widget.content['intro'] as String? ??
              '')
          .hashCode
          .toString();

  Set<int> get completed =>
      _completedByPlan.putIfAbsent(planKey, () => <int>{});

  @override
  Widget build(BuildContext context) {
    final intro = widget.content['intro'] as String? ?? '';
    final focus = widget.content['focus'] as String? ?? '';
    final readings = _readings();
    final total = readings.length;
    final done = completed.length.clamp(0, total);
    final progress = total == 0 ? 0.0 : done / total;
    final borderColor = done == total && total > 0
        ? const Color(0xFF247A4D)
        : Color.lerp(
            const Color(0xFFD8C98B),
            const Color(0xFF247A4D),
            progress,
          )!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8DF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: done == total && total > 0 ? 3 : 1.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (intro.isNotEmpty) ...[
            Text(
              intro,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
            const SizedBox(height: 8),
          ],
          if (focus.isNotEmpty) ...[
            Text(
              focus,
              style: const TextStyle(color: Color(0xFF5F6D66), height: 1.4),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: progress,
                    backgroundColor: const Color(0xFFE9DFC0),
                    color: const Color(0xFF247A4D),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$done/$total gelezen',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF20312E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 680;
              final tileWidth = isNarrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: readings.map((reading) {
                  final index = reading.index;
                  final isDone = completed.contains(index);
                  return SizedBox(
                    width: tileWidth,
                    child: _ReadingTile(
                      dayLabel: reading.dayLabel,
                      reference: reading.reference,
                      theme: reading.theme,
                      isDone: isDone,
                      onOpen: () => showDialog<void>(
                        context: context,
                        builder: (_) => BibleReaderDialog(
                          reference: reading.reference,
                          blockContext: widget.blockContext,
                        ),
                      ),
                      onToggle: () {
                        final nextDone = !isDone;
                        setState(() {
                          if (!nextDone) {
                            completed.remove(index);
                          } else {
                            completed.add(index);
                          }
                        });
                        ActivityTracker(
                          widget.blockContext,
                        ).track('reading_plan_toggled', {
                          'day': reading.dayLabel,
                          'reference': reading.reference,
                          'item_completed': nextDone,
                          'completed_count': completed.length,
                          'total': total,
                          'block_completed':
                              total > 0 && completed.length == total,
                        });
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<ReadingPlanItem> _readings() {
    final raw = widget.content['readings'];
    if (raw is List) {
      return raw
          .asMap()
          .entries
          .map((entry) {
            final item = entry.value;
            if (item is Map<String, dynamic>) {
              return ReadingPlanItem(
                index: entry.key,
                dayLabel: item['day'] as String? ?? 'Dag ${entry.key + 1}',
                reference: item['reference'] as String? ?? '',
                theme: item['theme'] as String? ?? '',
              );
            }
            return ReadingPlanItem(
              index: entry.key,
              dayLabel: 'Dag ${entry.key + 1}',
              reference: '$item',
              theme: '',
            );
          })
          .where((item) => item.reference.isNotEmpty)
          .toList();
    }

    final references = widget.content['references'];
    if (references is List) {
      return references
          .asMap()
          .entries
          .map((entry) {
            return ReadingPlanItem(
              index: entry.key,
              dayLabel: 'Dag ${entry.key + 1}',
              reference: '${entry.value}',
              theme: '',
            );
          })
          .where((item) => item.reference.isNotEmpty)
          .toList();
    }

    return const [];
  }
}

class ReadingPlanItem {
  const ReadingPlanItem({
    required this.index,
    required this.dayLabel,
    required this.reference,
    required this.theme,
  });

  final int index;
  final String dayLabel;
  final String reference;
  final String theme;
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    required this.dayLabel,
    required this.reference,
    required this.theme,
    required this.isDone,
    required this.onOpen,
    required this.onToggle,
  });

  final String dayLabel;
  final String reference;
  final String theme;
  final bool isDone;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDone ? const Color(0xFFE5F3EA) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDone ? const Color(0xFF247A4D) : const Color(0xFFE3DED2),
            ),
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: onToggle,
                icon: Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                tooltip: isDone
                    ? 'Markeer als ongelezen'
                    : 'Markeer als gelezen',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel,
                      style: const TextStyle(
                        color: Color(0xFF66716C),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reference,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (theme.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        theme,
                        style: const TextStyle(
                          color: Color(0xFF5F6D66),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, size: 18, color: Color(0xFF5F7A6A)),
            ],
          ),
        ),
      ),
    );
  }
}

class BibleBlock extends StatelessWidget {
  const BibleBlock({
    super.key,
    required this.content,
    required this.blockContext,
  });

  final Map<String, dynamic> content;
  final BlockContext blockContext;

  @override
  Widget build(BuildContext context) {
    final references = <String>[
      if (content['reference'] is String) content['reference'] as String,
      if (content['references'] is List)
        ...(content['references'] as List).map((item) => '$item'),
    ];
    final questions = (content['questions'] as List<dynamic>? ?? const [])
        .map((item) => '$item')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content['intro'] is String) ...[
          Text(content['intro'] as String),
          const SizedBox(height: 14),
        ],
        if (references.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: references.map((reference) {
              return FilledButton.icon(
                onPressed: () async {
                  final openedAt = DateTime.now();
                  ActivityTracker(
                    blockContext,
                  ).track('bible_opened', {'reference': reference});
                  await showDialog<void>(
                    context: context,
                    builder: (_) => BibleReaderDialog(
                      reference: reference,
                      blockContext: blockContext,
                    ),
                  );
                  final secondsOpen = DateTime.now()
                      .difference(openedAt)
                      .inSeconds;
                  if (secondsOpen >= 5) {
                    await ActivityTracker(blockContext).track('bible_read', {
                      'reference': reference,
                      'seconds_open': secondsOpen,
                      'completed': true,
                    });
                  }
                },
                icon: const Icon(Icons.menu_book),
                label: Text(reference),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (questions.isNotEmpty) ...[
          Text('Vragen', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          QuestionFlow(questions: questions, blockContext: blockContext),
        ],
      ],
    );
  }
}

class BibleReaderDialog extends StatelessWidget {
  const BibleReaderDialog({
    super.key,
    required this.reference,
    this.blockContext,
  });

  final String reference;
  final BlockContext? blockContext;

  @override
  Widget build(BuildContext context) {
    final api = HouvastApi();

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
        child: FutureBuilder<List<dynamic>>(
          future: api.getBibleTranslations(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final translations = snapshot.data!
                .cast<Map<String, dynamic>>()
                .map((item) => item['id'] as String)
                .toList();

            return BibleReaderTabs(
              reference: reference,
              translations: translations,
              blockContext: blockContext,
            );
          },
        ),
      ),
    );
  }
}

class BibleReaderTabs extends StatefulWidget {
  const BibleReaderTabs({
    super.key,
    required this.reference,
    required this.translations,
    this.blockContext,
  });

  final String reference;
  final List<String> translations;
  final BlockContext? blockContext;

  @override
  State<BibleReaderTabs> createState() => _BibleReaderTabsState();
}

class _BibleReaderTabsState extends State<BibleReaderTabs>
    with SingleTickerProviderStateMixin {
  late TabController controller;

  @override
  void initState() {
    super.initState();
    controller = _createController();
    controller.addListener(_saveSelectedTranslation);
  }

  @override
  void didUpdateWidget(covariant BibleReaderTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.translations.join('|') == widget.translations.join('|')) {
      return;
    }
    controller.removeListener(_saveSelectedTranslation);
    controller.dispose();
    controller = _createController();
    controller.addListener(_saveSelectedTranslation);
  }

  @override
  void dispose() {
    controller.removeListener(_saveSelectedTranslation);
    controller.dispose();
    super.dispose();
  }

  TabController _createController() {
    final preferred = BibleTranslationPreferences.load();
    final preferredIndex = widget.translations.indexWhere(
      (translation) => translation == preferred,
    );
    return TabController(
      length: widget.translations.length,
      initialIndex: preferredIndex >= 0 ? preferredIndex : 0,
      vsync: this,
    );
  }

  void _saveSelectedTranslation() {
    if (controller.index < 0 ||
        controller.index >= widget.translations.length) {
      return;
    }
    BibleTranslationPreferences.save(widget.translations[controller.index]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.reference,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        TabBar(
          controller: controller,
          isScrollable: true,
          tabs: widget.translations
              .map((translation) => Tab(text: translation))
              .toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: widget.translations
                .map(
                  (translation) => BiblePassageView(
                    reference: widget.reference,
                    translation: translation,
                    blockContext: widget.blockContext,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class BiblePassageView extends StatefulWidget {
  const BiblePassageView({
    super.key,
    required this.reference,
    required this.translation,
    this.blockContext,
  });

  final String reference;
  final String translation;
  final BlockContext? blockContext;

  @override
  State<BiblePassageView> createState() => _BiblePassageViewState();
}

class _BiblePassageViewState extends State<BiblePassageView> {
  static final Map<String, Map<int, VerseAnnotation>> _annotations = {};

  String get boardKey => '${widget.translation}:${widget.reference}';

  Map<int, VerseAnnotation> get annotations =>
      _annotations.putIfAbsent(boardKey, () => <int, VerseAnnotation>{});

  @override
  Widget build(BuildContext context) {
    final api = HouvastApi();

    return FutureBuilder<Map<String, dynamic>>(
      future: api.getBiblePassage(
        reference: widget.reference,
        translation: widget.translation,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final verses = (data['verses'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

        if (verses.isEmpty) {
          final sourceUrl = data['source_url'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF7A4D00)),
                const SizedBox(height: 12),
                Text(
                  data['message'] as String? ??
                      'Deze passage kon niet uit de lokale Bijbelbestanden worden gelezen.',
                ),
                const SizedBox(height: 12),
                if (sourceUrl.isNotEmpty) ...[
                  Text('Bron: $sourceUrl'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(sourceUrl),
                      webOnlyWindowName: '_blank',
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open passage online'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(22),
          itemCount: verses.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6EF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE3DED2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app, color: Color(0xFF5F7A6A)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tik op een vers om te highlighten, een korte notitie te maken of een emotie te plaatsen.',
                      ),
                    ),
                  ],
                ),
              );
            }

            if (index == verses.length + 1) {
              return BibleAnnotationBoard(
                annotations: annotations,
                verses: verses,
              );
            }

            final verse = verses[index - 1];
            final number = verse['number'] as int;
            final annotation = annotations[number];
            return BibleVerseRow(
              number: number,
              text: verse['text'] as String,
              annotation: annotation,
              onTap: () => openVerseActions(
                number: number,
                text: verse['text'] as String,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> openVerseActions({
    required int number,
    required String text,
  }) async {
    final current = annotations[number] ?? const VerseAnnotation();
    final noteController = TextEditingController(text: current.note);
    Color selectedColor = current.highlightColor ?? const Color(0xFFFFE7A8);
    String selectedEmoji = current.emoji;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Vers $number',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6EF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE3DED2)),
                      ),
                      child: Text(text),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Highlight',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          const [
                            Color(0xFFFFE7A8),
                            Color(0xFFD7F0DD),
                            Color(0xFFDCEBFF),
                            Color(0xFFF3D6E8),
                          ].map((color) {
                            final active = selectedColor == color;
                            return InkWell(
                              onTap: () =>
                                  setSheetState(() => selectedColor = color),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: active
                                        ? const Color(0xFF20312E)
                                        : const Color(0x66808A84),
                                    width: active ? 3 : 1,
                                  ),
                                ),
                                child: active
                                    ? const Icon(Icons.check, size: 20)
                                    : null,
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Emotie bij dit vers',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['💡', '🙏', '❤️', '❓', '🔥', '🌱'].map((
                        emoji,
                      ) {
                        final active = selectedEmoji == emoji;
                        return ChoiceChip(
                          selected: active,
                          label: Text(
                            emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          onSelected: (_) => setSheetState(() {
                            selectedEmoji = active ? '' : emoji;
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Notitie',
                        hintText:
                            'Wat valt je op, wat raakt je, of wat vraag je je af?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() => annotations.remove(number));
                            final blockContext = widget.blockContext;
                            if (blockContext != null) {
                              ActivityTracker(
                                blockContext,
                              ).track('bible_annotation_cleared', {
                                'reference': widget.reference,
                                'translation': widget.translation,
                                'verse': number,
                              });
                            }
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Wis'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () {
                            final note = noteController.text.trim();
                            setState(() {
                              annotations[number] = VerseAnnotation(
                                highlightColor: selectedColor,
                                note: note,
                                emoji: selectedEmoji,
                              );
                            });
                            final blockContext = widget.blockContext;
                            if (blockContext != null) {
                              ActivityTracker(
                                blockContext,
                              ).track('bible_annotation_saved', {
                                'reference': widget.reference,
                                'translation': widget.translation,
                                'verse': number,
                                'highlight': selectedColor.toARGB32(),
                                'note': note,
                                'emoji': selectedEmoji,
                              });
                            }
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Zet op leesbord'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }
}

class BibleAnnotationBoard extends StatelessWidget {
  const BibleAnnotationBoard({
    super.key,
    required this.annotations,
    required this.verses,
  });

  final Map<int, VerseAnnotation> annotations;
  final List<Map<String, dynamic>> verses;

  @override
  Widget build(BuildContext context) {
    final verseTextByNumber = {
      for (final verse in verses)
        verse['number'] as int: verse['text'] as String,
    };
    final items =
        annotations.entries
            .where(
              (entry) =>
                  entry.value.highlightColor != null ||
                  entry.value.note.isNotEmpty ||
                  entry.value.emoji.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF20312E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leesbord',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF2B423D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF49665E)),
              ),
              child: const Text(
                'Nog geen highlights of notities.',
                style: TextStyle(color: Color(0xFFCFE0D6)),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items.map((entry) {
                final annotation = entry.value;
                return Container(
                  width: 250,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: annotation.highlightColor ?? Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Vers ${entry.key}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          if (annotation.emoji.isNotEmpty)
                            Text(
                              annotation.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        verseTextByNumber[entry.key] ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                      if (annotation.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          annotation.note,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF20312E),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class VerseAnnotation {
  const VerseAnnotation({this.highlightColor, this.note = '', this.emoji = ''});

  final Color? highlightColor;
  final String note;
  final String emoji;
}

class BibleVerseRow extends StatelessWidget {
  const BibleVerseRow({
    super.key,
    required this.number,
    required this.text,
    required this.annotation,
    required this.onTap,
  });

  final int number;
  final String text;
  final VerseAnnotation? annotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        annotation?.highlightColor ?? Colors.white.withValues(alpha: 0);
    final hasAnnotation = annotation != null;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasAnnotation
                      ? const Color(0xFF20312E)
                      : const Color(0xFFE9F1EC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: hasAnnotation
                        ? Colors.white
                        : const Color(0xFF24302F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(height: 1.45, fontSize: 15.5),
                    ),
                    if ((annotation?.note ?? '').isNotEmpty ||
                        (annotation?.emoji ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if ((annotation?.emoji ?? '').isNotEmpty)
                            Text(
                              annotation!.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          if ((annotation?.note ?? '').isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.76),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                annotation!.note,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF40524B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.touch_app, size: 18, color: Color(0xFF75837D)),
            ],
          ),
        ),
      ),
    );
  }
}

class QuestionFlow extends StatefulWidget {
  const QuestionFlow({
    super.key,
    required this.questions,
    this.minCharacters = 0,
    this.labelPrefix = 'Vraag',
    this.hintText = 'Typ je antwoord...',
    this.blockContext,
  });

  final List<String> questions;
  final int minCharacters;
  final String labelPrefix;
  final String hintText;
  final BlockContext? blockContext;

  @override
  State<QuestionFlow> createState() => _QuestionFlowState();
}

class _QuestionFlowState extends State<QuestionFlow> {
  int activeIndex = 0;
  late final List<TextEditingController> controllers;
  final Map<int, String> lastTrackedAnswers = {};

  @override
  void initState() {
    super.initState();
    controllers = widget.questions.map((_) => TextEditingController()).toList();
    for (var index = 0; index < controllers.length; index++) {
      controllers[index].addListener(() => _onAnswerChanged(index));
    }
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) return const SizedBox.shrink();
    final question = widget.questions[activeIndex];
    final entries = <Map<String, String>>[
      for (var index = 0; index < controllers.length; index++)
        if (_isValidAnswer(controllers[index].text))
          {
            'name': AppSession.current?.username ?? 'Gast',
            'label': '${widget.labelPrefix} ${index + 1}',
            'answer': controllers[index].text.trim(),
          },
    ];
    final activeText = controllers[activeIndex].text.trim();
    final remaining = widget.minCharacters - activeText.length;
    final answerIsTooShort =
        widget.minCharacters > 0 && activeText.isNotEmpty && remaining > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3DED2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.labelPrefix} ${activeIndex + 1} van ${widget.questions.length}',
                style: const TextStyle(
                  color: Color(0xFF66716C),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(question, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controllers[activeIndex],
                minLines: 2,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (widget.minCharacters > 0) ...[
                const SizedBox(height: 8),
                Text(
                  answerIsTooShort
                      ? 'Schrijf nog ongeveer $remaining tekens, liefst als complete zin.'
                      : activeText.isEmpty
                      ? 'Minimaal ${widget.minCharacters} tekens per antwoord.'
                      : 'Mooi, dit is lang genoeg voor het groepsbord.',
                  style: TextStyle(
                    color: answerIsTooShort
                        ? const Color(0xFF8A5B16)
                        : const Color(0xFF5F7A6A),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: activeIndex == 0
                        ? null
                        : () => setState(() => activeIndex--),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Vorige'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: activeIndex == widget.questions.length - 1
                        ? null
                        : () => setState(() => activeIndex++),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Volgende'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BlackboardBubbles(entries: entries, blockContext: widget.blockContext),
      ],
    );
  }

  bool _isValidAnswer(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    return text.length >= widget.minCharacters;
  }

  void _onAnswerChanged(int index) {
    setState(() {});
    final blockContext = widget.blockContext;
    if (blockContext == null || index < 0 || index >= controllers.length) {
      return;
    }
    final answer = controllers[index].text.trim();
    if (!_isValidAnswer(answer) || lastTrackedAnswers[index] == answer) return;
    Future<void>.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted ||
          controllers[index].text.trim() != answer ||
          lastTrackedAnswers[index] == answer) {
        return;
      }
      lastTrackedAnswers[index] = answer;
      await ActivityTracker(blockContext).track('question_answered', {
        'question_index': index + 1,
        'question': widget.questions[index],
        'answer': answer,
        'answered_count': controllers
            .where((controller) => _isValidAnswer(controller.text))
            .length,
        'total_questions': controllers.length,
        'completed': controllers.every(
          (controller) => _isValidAnswer(controller.text),
        ),
      });
    });
  }
}

class BlackboardBubbles extends StatefulWidget {
  const BlackboardBubbles({
    super.key,
    required this.entries,
    this.blockContext,
  });

  final List<Map<String, String>> entries;
  final BlockContext? blockContext;

  @override
  State<BlackboardBubbles> createState() => _BlackboardBubblesState();
}

class _BlackboardBubblesState extends State<BlackboardBubbles> {
  final Map<String, List<String>> replies = {};
  final Map<String, List<String>> emojiReplies = {};
  final Map<String, TextEditingController> replyControllers = {};
  String? openReplyKey;

  @override
  void dispose() {
    for (final controller in replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF20312E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Groepsbord',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.entries.isEmpty
                ? 'Typ hierboven iets. Je antwoord verschijnt hier direct.'
                : 'Tik op een wolkje om op die persoon te reageren.',
            style: const TextStyle(color: Color(0xFFCFE0D6), fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (widget.entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF2B423D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF49665E)),
              ),
              child: const Text(
                'Nog geen antwoorden.',
                style: TextStyle(color: Color(0xFFCFE0D6)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth < 560
                    ? constraints.maxWidth
                    : 360.0;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.entries.map((entry) {
                    final key = _entryKey(entry);
                    return SizedBox(
                      width: cardWidth,
                      child: _bubble(entry, key),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  String _entryKey(Map<String, String> entry) {
    return '${entry['name']}|${entry['label']}|${entry['answer']}';
  }

  Widget _bubble(Map<String, String> entry, String key) {
    final controller = replyControllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
    final itemReplies = replies[key] ?? const [];
    final isOpen = openReplyKey == key;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry['name']!,
                  style: const TextStyle(
                    color: Color(0xFF5F7A6A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _labelColor(entry['label'] ?? ''),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry['label']!,
                  style: const TextStyle(
                    color: Color(0xFF24302F),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(entry['answer']!),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              setState(() {
                openReplyKey = isOpen ? null : key;
              });
            },
            icon: const Icon(Icons.reply, size: 18),
            label: Text(isOpen ? 'Sluiten' : 'Reageer'),
          ),
          EmojiReactionBar(
            selected: emojiReplies[key] ?? const [],
            onEmoji: (emoji) {
              setState(() {
                emojiReplies.putIfAbsent(key, () => <String>[]).add(emoji);
              });
              _trackBoardAction('blackboard_emoji', entry, {'emoji': emoji});
            },
          ),
          if (isOpen) ...[
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitReply(entry, key, controller),
              decoration: InputDecoration(
                hintText: 'Reageer op ${entry['name']}...',
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: 'Plaats reactie',
                  icon: const Icon(Icons.send),
                  onPressed: () => _submitReply(entry, key, controller),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _submitReply(entry, key, controller),
                child: const Text('Plaats'),
              ),
            ),
          ],
          if (itemReplies.isNotEmpty) ...[
            const Divider(height: 18),
            ...itemReplies.map(
              (reply) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F1EC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jij reageert',
                        style: TextStyle(
                          color: Color(0xFF365847),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(reply),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _labelColor(String label) {
    final match = RegExp(r'(\d+)').firstMatch(label);
    final index = int.tryParse(match?.group(1) ?? '') ?? 1;
    const colors = [
      Color(0xFFE9F1EC),
      Color(0xFFFFF1D6),
      Color(0xFFE8EEF9),
      Color(0xFFF4E7EF),
      Color(0xFFEDE9F7),
      Color(0xFFE8F3F2),
    ];
    return colors[(index - 1) % colors.length];
  }

  void _trackBoardAction(
    String action,
    Map<String, String> entry,
    Map<String, dynamic> value,
  ) {
    final blockContext = widget.blockContext;
    if (blockContext == null) return;
    ActivityTracker(blockContext).track(action, {
      'target_name': entry['name'] ?? '',
      'target_label': entry['label'] ?? '',
      'target_answer': entry['answer'] ?? '',
      ...value,
    });
  }

  void _submitReply(
    Map<String, String> entry,
    String key,
    TextEditingController controller,
  ) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      replies.putIfAbsent(key, () => []).add(text);
      controller.clear();
      openReplyKey = null;
    });
    _trackBoardAction('blackboard_reply', entry, {'reply': text});
  }
}

class EmojiReactionBar extends StatelessWidget {
  const EmojiReactionBar({
    super.key,
    required this.selected,
    required this.onEmoji,
  });

  final List<String> selected;
  final ValueChanged<String> onEmoji;

  static const emojis = ['👍', '❤️', '🙏', '💡', '❓'];

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final emoji in selected) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: emojis.map((emoji) {
        final count = counts[emoji] ?? 0;
        return InkWell(
          onTap: () => onEmoji(emoji),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: count > 0
                  ? const Color(0xFFE9F1EC)
                  : const Color(0xFFF8F6EF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE3DED2)),
            ),
            child: Text(
              count > 0 ? '$emoji $count' : emoji,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DistributionBlockState extends State<DistributionBlock> {
  static final Map<String, List<Map<String, dynamic>>> _groupSubmissions = {};

  late final int targetTotal;
  late final String unit;
  late final int step;
  late final List<Map<String, dynamic>> options;
  late final Map<String, int> values;
  late final String boardKey;
  final explanationController = TextEditingController();
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    targetTotal = widget.content['total'] as int? ?? 100;
    unit = widget.content['unit'] as String? ?? '%';
    step = widget.content['step'] as int? ?? 5;
    options = (widget.content['options'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    values = {
      for (final option in options)
        option['id'] as String: option['default'] as int? ?? 0,
    };
    boardKey =
        widget.content['id'] as String? ??
        widget.content['prompt'] as String? ??
        identityHashCode(widget.content).toString();
  }

  @override
  void dispose() {
    explanationController.dispose();
    super.dispose();
  }

  int get total => values.values.fold(0, (sum, value) => sum + value);

  bool get isComplete => total == targetTotal;

  @override
  Widget build(BuildContext context) {
    final prompt = widget.content['prompt'] as String?;
    final afterPrompt = widget.content['after_prompt'] as String?;
    final shareWithGroup = widget.content['share_with_group'] as bool? ?? true;
    final submissions =
        _groupSubmissions[boardKey] ?? const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prompt != null) ...[Text(prompt), const SizedBox(height: 14)],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3DED2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Totaal: $total / $targetTotal$unit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _statusBadge(),
                ],
              ),
              const SizedBox(height: 14),
              ...options.map(_distributionRow),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isComplete
                          ? 'Je verdeling is precies $targetTotal$unit.'
                          : total < targetTotal
                          ? 'Verdeel nog ${targetTotal - total}$unit voordat je klaar bent.'
                          : 'Je zit boven $targetTotal$unit. Verlaag eerst een waarde.',
                      style: const TextStyle(
                        color: Color(0xFF66716C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: isComplete
                        ? () => _submitDistribution(shareWithGroup)
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Klaar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (afterPrompt != null) ...[
          const SizedBox(height: 14),
          Text(
            afterPrompt,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: explanationController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Schrijf je reactie...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isComplete
                  ? () => _submitDistribution(shareWithGroup)
                  : null,
              icon: const Icon(Icons.send),
              label: Text(
                submitted ? 'Update toelichting' : 'Plaats toelichting',
              ),
            ),
          ),
        ],
        if (shareWithGroup) ...[
          const SizedBox(height: 14),
          DistributionGroupBoard(
            unit: unit,
            options: options,
            submissions: submissions,
            blockContext: widget.blockContext,
          ),
        ],
      ],
    );
  }

  Widget _distributionRow(Map<String, dynamic> option) {
    final id = option['id'] as String;
    final label = option['label'] as String? ?? id;
    final description = option['description'] as String? ?? '';
    final value = values[id] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: const TextStyle(color: Color(0xFF66716C)),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                child: TextFormField(
                  key: ValueKey('distribution-$id-$value'),
                  initialValue: '$value',
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixText: unit,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (raw) {
                    final parsed = int.tryParse(raw);
                    if (parsed == null) return;
                    _setValue(id, parsed.clamp(0, targetTotal));
                  },
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: targetTotal.toDouble(),
            divisions: (targetTotal / step).floor().clamp(1, 1000),
            label: '$value$unit',
            onChanged: (next) => _setValue(id, _roundToStep(next.round())),
          ),
        ],
      ),
    );
  }

  void _setValue(String id, int value) {
    setState(() {
      submitted = false;
      values[id] = value.clamp(0, _maxForOption(id));
    });
  }

  int _maxForOption(String id) {
    final current = values[id] ?? 0;
    final otherTotal = total - current;
    return (targetTotal - otherTotal).clamp(0, targetTotal);
  }

  int _roundToStep(int value) {
    if (step <= 1) return value;
    return (value / step).round() * step;
  }

  void _submitDistribution(bool shareWithGroup) {
    setState(() {
      submitted = true;
      if (shareWithGroup) {
        final submission = {
          'name': AppSession.current?.username ?? 'Gast',
          'values': Map<String, int>.from(values),
          'explanation': explanationController.text.trim(),
        };
        final list = _groupSubmissions.putIfAbsent(
          boardKey,
          () => <Map<String, dynamic>>[],
        );
        list.removeWhere((item) => item['name'] == submission['name']);
        list.add(submission);
      }
    });
    ActivityTracker(widget.blockContext).track('distribution_submitted', {
      'values': Map<String, int>.from(values),
      'total': total,
      'target_total': targetTotal,
      'unit': unit,
      'shared_with_group': shareWithGroup,
      'explanation': explanationController.text.trim(),
      'completed': true,
    });
  }

  Widget _statusBadge() {
    final color = isComplete
        ? const Color(0xFFE9F1EC)
        : const Color(0xFFFFF1D6);
    final textColor = isComplete
        ? const Color(0xFF365847)
        : const Color(0xFF7A4D00);
    final text = isComplete
        ? 'Klaar'
        : total < targetTotal
        ? 'Nog ${targetTotal - total}$unit'
        : '${total - targetTotal}$unit te veel';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class DistributionGroupBoard extends StatefulWidget {
  const DistributionGroupBoard({
    super.key,
    required this.unit,
    required this.options,
    required this.submissions,
    required this.blockContext,
  });

  final String unit;
  final List<Map<String, dynamic>> options;
  final List<Map<String, dynamic>> submissions;
  final BlockContext blockContext;

  @override
  State<DistributionGroupBoard> createState() => _DistributionGroupBoardState();
}

class _DistributionGroupBoardState extends State<DistributionGroupBoard> {
  final Map<String, List<String>> emojiReplies = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF20312E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Groepsbord',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hier verschijnen verdelingen nadat deelnemers op Klaar drukken.',
            style: TextStyle(color: Color(0xFFCFE0D6), fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (widget.submissions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF2B423D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF49665E)),
              ),
              child: const Text(
                'Nog geen verdelingen gedeeld.',
                style: TextStyle(color: Color(0xFFCFE0D6)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth < 620
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.submissions.map((submission) {
                    return SizedBox(
                      width: cardWidth,
                      child: _submissionCard(submission),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _submissionCard(Map<String, dynamic> submission) {
    final key = '${submission['name']}|${submission['values']}';
    final explanation = submission['explanation'] as String? ?? '';
    final values = (submission['values'] as Map).map(
      (key, value) =>
          MapEntry('$key', value as int? ?? int.tryParse('$value') ?? 0),
    );
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            submission['name'] as String? ?? 'Deelnemer',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...widget.options.map((option) {
            final id = option['id'] as String? ?? '';
            final label = option['label'] as String? ?? id;
            final value = values[id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  const SizedBox(width: 8),
                  Text(
                    '$value${widget.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }),
          if (explanation.isNotEmpty) ...[
            const Divider(height: 18),
            Text(
              explanation,
              style: const TextStyle(
                color: Color(0xFF40524B),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 4),
          EmojiReactionBar(
            selected: emojiReplies[key] ?? const [],
            onEmoji: (emoji) {
              setState(() {
                emojiReplies.putIfAbsent(key, () => <String>[]).add(emoji);
              });
              ActivityTracker(widget.blockContext).track('distribution_emoji', {
                'target_name': submission['name'] as String? ?? '',
                'target_values': values,
                'emoji': emoji,
              });
            },
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend niet bereikbaar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(error),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Opnieuw proberen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
