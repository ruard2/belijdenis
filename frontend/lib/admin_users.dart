import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'auth_token.dart';

/// Beheer van deelnemers: aanmaken, pincode resetten, voortgang bekijken.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> chapters = [];
  bool loading = true;
  String? error;
  String filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Uri _uri(String path) => Uri.parse('${widget.apiBaseUrl}$path');

  String _errorText(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] is String) return body['detail'] as String;
    } catch (_) {}
    return 'Er ging iets mis (${response.statusCode}).';
  }

  Future<http.Response> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, _uri(path));
    request.headers.addAll(AuthToken.headers(json: true));
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorText(response));
    }
    return response;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final usersResponse = await _send('GET', '/admin/users');
      final chaptersResponse = await _send('GET', '/courses/belijdenis/chapters');
      setState(() {
        users = (jsonDecode(usersResponse.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        chapters = (jsonDecode(chaptersResponse.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        loading = false;
      });
    } catch (exception) {
      setState(() {
        error = '$exception'.replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (exception) {
      if (mounted) _toast('$exception'.replaceFirst('Exception: ', ''));
    }
  }

  // ---------------------------------------------------------------- acties

  Future<void> _addUser() async {
    final nameController = TextEditingController();
    final names = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deelnemers toevoegen'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Eén naam per regel. Gebruikersnaam en pincode worden automatisch gemaakt.',
                style: TextStyle(color: Color(0xFF66716C)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                minLines: 3,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Jan de Vries\nAnna Bakker',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              nameController.text
                  .split('\n')
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .toList(),
            ),
            icon: const Icon(Icons.person_add),
            label: const Text('Aanmaken'),
          ),
        ],
      ),
    );
    if (names == null || names.isEmpty) return;

    final created = <Map<String, dynamic>>[];
    await _run(() async {
      for (final name in names) {
        final response = await _send('POST', '/admin/users', {
          'display_name': name,
        });
        created.add(jsonDecode(response.body) as Map<String, dynamic>);
      }
    });
    await _load();
    if (created.isNotEmpty && mounted) await _showCredentials(created);
  }

  Future<void> _resetPin(Map<String, dynamic> user) async {
    final confirmed = await _confirm(
      'Nieuwe pincode voor ${user['display_name']}?',
      'De oude pincode werkt daarna niet meer en ${user['display_name']} wordt op alle apparaten uitgelogd.',
      'Nieuwe pincode',
    );
    if (!confirmed) return;
    await _run(() async {
      final response = await _send('POST', '/admin/users/${user['id']}/reset-pin');
      await _showCredentials([jsonDecode(response.body) as Map<String, dynamic>]);
    });
  }

  Future<void> _rename(Map<String, dynamic> user) async {
    final controller = TextEditingController(text: user['display_name'] as String);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naam wijzigen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Naam'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      await _send('PATCH', '/admin/users/${user['id']}', {
        'display_name': name.trim(),
      });
      await _load();
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final active = user['active'] == true;
    await _run(() async {
      await _send('PATCH', '/admin/users/${user['id']}', {'active': !active});
      await _load();
      _toast(active ? 'Account gedeactiveerd.' : 'Account weer actief.');
    });
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final confirmed = await _confirm(
      '${user['display_name']} verwijderen?',
      'Het account en de hoofdstuk-voortgang worden verwijderd. Dit kan niet ongedaan worden.',
      'Verwijderen',
    );
    if (!confirmed) return;
    await _run(() async {
      await _send('DELETE', '/admin/users/${user['id']}');
      await _load();
    });
  }

  Future<void> _editProgress(Map<String, dynamic> user) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ProgressDialog(
        user: user,
        chapters: chapters,
        onToggle: (chapterId, completed) => _send(
          'POST',
          '/admin/users/${user['id']}/chapters/$chapterId',
          {'completed': completed},
        ),
      ),
    );
    await _load();
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _showCredentials(List<Map<String, dynamic>> created) async {
    final site = Uri.base.origin;
    final text = created
        .map(
          (user) =>
              '${user['display_name']}\n'
              'Website: $site\n'
              'Gebruikersnaam: ${user['username']}\n'
              'Pincode: ${user['pin']}',
        )
        .join('\n\n');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.key, color: Color(0xFF247A4D)),
        title: Text(
          created.length == 1 ? 'Inloggegevens' : '${created.length} deelnemers aangemaakt',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Noteer of kopieer de pincode nu: hij wordt niet opgeslagen en is later niet meer te zien. '
                    'Vergeten? Maak dan een nieuwe pincode aan.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
                ...created.map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['display_name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SelectableText(
                          'Gebruikersnaam: ${user['username']}\nPincode: ${user['pin']}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gekopieerd naar klembord.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Kopiëren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Klaar'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- UI

  String _lastLogin(Map<String, dynamic> user) {
    final raw = user['last_login_at'] as String?;
    if (raw == null || raw.isEmpty) return 'Nog nooit ingelogd';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Laatst ingelogd ${two(date.day)}-${two(date.month)}-${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final visible = users
        .where(
          (user) =>
              filter.isEmpty ||
              '${user['display_name']} ${user['username']}'.toLowerCase().contains(
                filter.toLowerCase(),
              ),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF20312E),
        foregroundColor: Colors.white,
        title: const Text('Deelnemers'),
        actions: [
          IconButton(
            tooltip: 'Vernieuwen',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Deelnemer toevoegen'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Opnieuw')),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Zoek deelnemer',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) => setState(() => filter = value),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${users.length} deelnemers · ${chapters.length} hoofdstukken gepubliceerd',
                      style: const TextStyle(color: Color(0xFF66716C)),
                    ),
                    const SizedBox(height: 12),
                    if (users.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nog geen deelnemers. Klik op "Deelnemer toevoegen" om te beginnen.',
                          ),
                        ),
                      ),
                    ...visible.map(_userCard),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final active = user['active'] == true;
    final completed = (user['completed_chapters'] as List<dynamic>? ?? []).length;
    final total = chapters.length;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: active ? const Color(0xFF365847) : const Color(0xFFB8BEBB),
          foregroundColor: Colors.white,
          child: Text(
            (user['display_name'] as String).isEmpty
                ? '?'
                : (user['display_name'] as String)[0].toUpperCase(),
          ),
        ),
        title: Text(
          '${user['display_name']}${active ? '' : ' (gedeactiveerd)'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gebruikersnaam: ${user['username']}'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : (completed / total).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE9F1EC),
                      color: const Color(0xFF247A4D),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$completed/$total · ${user['xp']} XP'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _lastLogin(user),
              style: const TextStyle(fontSize: 12, color: Color(0xFF66716C)),
            ),
          ],
        ),
        onTap: () => _editProgress(user),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'pin':
                _resetPin(user);
              case 'progress':
                _editProgress(user);
              case 'rename':
                _rename(user);
              case 'active':
                _toggleActive(user);
              case 'delete':
                _delete(user);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'pin',
              child: ListTile(leading: Icon(Icons.key), title: Text('Nieuwe pincode')),
            ),
            const PopupMenuItem(
              value: 'progress',
              child: ListTile(leading: Icon(Icons.checklist), title: Text('Voortgang')),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: ListTile(leading: Icon(Icons.edit), title: Text('Naam wijzigen')),
            ),
            PopupMenuItem(
              value: 'active',
              child: ListTile(
                leading: Icon(active ? Icons.block : Icons.check_circle_outline),
                title: Text(active ? 'Deactiveren' : 'Activeren'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Color(0xFF9E3E2F)),
                title: Text('Verwijderen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDialog extends StatefulWidget {
  const _ProgressDialog({
    required this.user,
    required this.chapters,
    required this.onToggle,
  });

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> chapters;
  final Future<void> Function(String chapterId, bool completed) onToggle;

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  late final Set<String> completed = {
    for (final item in (widget.user['completed_chapters'] as List<dynamic>? ?? []))
      '${(item as Map<String, dynamic>)['chapter_id']}',
  };
  String? busy;

  @override
  Widget build(BuildContext context) {
    var previousDone = true;
    return AlertDialog(
      title: Text('Voortgang ${widget.user['display_name']}'),
      content: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Vink een hoofdstuk aan om het als afgerond te markeren; daarmee gaat ook het volgende hoofdstuk open.',
              style: TextStyle(color: Color(0xFF66716C), fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...widget.chapters.map((chapter) {
              final id = chapter['id'] as String;
              final isDone = completed.contains(id);
              final locked = !previousDone;
              previousDone = isDone;
              return CheckboxListTile(
                value: isDone,
                onChanged: busy != null
                    ? null
                    : (value) async {
                        setState(() => busy = id);
                        try {
                          await widget.onToggle(id, value == true);
                          setState(() {
                            if (value == true) {
                              completed.add(id);
                            } else {
                              completed.remove(id);
                            }
                          });
                        } catch (exception) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$exception')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => busy = null);
                        }
                      },
                title: Text('${chapter['sort_order']}. ${chapter['title']}'),
                subtitle: Text(
                  isDone
                      ? 'Afgerond'
                      : locked
                      ? 'Op slot'
                      : 'Open – nog bezig',
                ),
                secondary: Icon(
                  isDone
                      ? Icons.check_circle
                      : locked
                      ? Icons.lock_outline
                      : Icons.play_circle_outline,
                  color: isDone ? const Color(0xFF247A4D) : const Color(0xFF66716C),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Sluiten'),
        ),
      ],
    );
  }
}
