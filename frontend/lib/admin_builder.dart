import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _configuredAdminApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

final String adminApiBaseUrl = _resolveAdminApiBaseUrl();

String _resolveAdminApiBaseUrl() {
  if (_configuredAdminApiBaseUrl.isNotEmpty) {
    return _configuredAdminApiBaseUrl;
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

class AdminBuilder extends StatefulWidget {
  const AdminBuilder({super.key, required this.onClose});

  final FutureOr<void> Function() onClose;

  @override
  State<AdminBuilder> createState() => _AdminBuilderState();
}

class _AdminBuilderState extends State<AdminBuilder> {
  List<Map<String, dynamic>> chapters = [];
  Map<String, dynamic>? chapter;
  int selectedBlockIndex = -1;
  bool loading = true;
  String? message;

  @override
  void initState() {
    super.initState();
    loadChapters();
  }

  Future<void> loadChapters() async {
    setState(() => loading = true);
    final response = await http.get(
      Uri.parse('$adminApiBaseUrl/admin/courses/belijdenis/chapters'),
    );
    final loaded = (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    setState(() {
      chapters = loaded;
      loading = false;
    });
  }

  Future<void> openChapter(String chapterId) async {
    final response = await http.get(
      Uri.parse('$adminApiBaseUrl/chapters/$chapterId'),
    );
    setState(() {
      chapter = jsonDecode(response.body) as Map<String, dynamic>;
      selectedBlockIndex = -1;
      message = null;
    });
  }

  void newChapter() {
    final next = chapters.length + 1;
    setState(() {
      chapter = {
        'id': 'belijdenis_${next.toString().padLeft(3, '0')}',
        'course_id': 'belijdenis',
        'slug': 'nieuw-hoofdstuk-$next',
        'title': 'Nieuw hoofdstuk',
        'subtitle': '',
        'description': '',
        'xp': 100,
        'status': 'draft',
        'sort_order': next,
        'blocks': <Map<String, dynamic>>[],
      };
      selectedBlockIndex = -1;
      message = null;
    });
  }

  Future<void> save() async {
    if (chapter == null) return;
    final response = await http.post(
      Uri.parse('$adminApiBaseUrl/admin/chapters/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(chapter),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      setState(() {
        chapter = jsonDecode(response.body) as Map<String, dynamic>;
        message = 'Opgeslagen in database';
      });
      await loadChapters();
    } else {
      setState(() => message = 'Opslaan mislukt: ${response.body}');
    }
  }

  Future<void> exportExcel() async {
    final uri = Uri.parse(
      '$adminApiBaseUrl/admin/courses/belijdenis/export.xlsx',
    );
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened) {
      setState(() => message = 'Export openen mislukt.');
    }
  }

  Future<void> importExcel() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(
        () => message = 'Import mislukt: bestand kon niet gelezen worden.',
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excel importeren?'),
        content: Text(
          'Dit vervangt alle hoofdstukken en blocks van deze cursus door "${file.name}". '
          'De huidige versie wordt eerst als archief bewaard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.archive),
            label: const Text('Archiveer en vervang'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => message = 'Excel importeren...');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$adminApiBaseUrl/admin/courses/belijdenis/import.xlsx'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        chapter = null;
        selectedBlockIndex = -1;
        message =
            'Import klaar: ${result['chapters']} hoofdstukken, ${result['blocks']} blocks. Archief #${result['archive_id']}.';
      });
      await loadChapters();
    } else {
      setState(() => message = 'Import mislukt: ${response.body}');
    }
  }

  Future<void> showActivity() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Statistieken'),
          content: SizedBox(
            width: 760,
            height: 520,
            child: FutureBuilder<http.Response>(
              future: http.get(
                Uri.parse('$adminApiBaseUrl/admin/activity?limit=200'),
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final response = snapshot.data!;
                if (response.statusCode < 200 || response.statusCode >= 300) {
                  return Text('Kon statistieken niet laden: ${response.body}');
                }
                final events = (jsonDecode(response.body) as List<dynamic>)
                    .cast<Map<String, dynamic>>();
                if (events.isEmpty) {
                  return const Text('Nog geen leerlingactiviteit opgeslagen.');
                }
                return ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final value = event['value'] as Map<String, dynamic>? ?? {};
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.analytics_outlined),
                      title: Text('${event['username']} - ${event['action']}'),
                      subtitle: Text(
                        '${event['chapter_id']} / ${event['block_id']}\n${jsonEncode(value)}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${event['created_at']}'
                            .replaceFirst('T', '\n')
                            .split('.')
                            .first,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Sluiten'),
            ),
          ],
        );
      },
    );
  }

  void updateChapter(String key, dynamic value) {
    setState(() => chapter![key] = value);
  }

  void addBlock(String type) {
    if (chapter == null) return;
    final blocks = (chapter!['blocks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final next = blocks.length + 1;
    blocks.add(defaultBlock(type, chapter!['id'] as String, next));
    setState(() => selectedBlockIndex = blocks.length - 1);
  }

  void moveBlock(int from, int delta) {
    final blocks = (chapter!['blocks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final to = from + delta;
    if (to < 0 || to >= blocks.length) return;
    final item = blocks.removeAt(from);
    blocks.insert(to, item);
    for (var i = 0; i < blocks.length; i++) {
      blocks[i]['sort_order'] = i + 1;
    }
    setState(() => selectedBlockIndex = to);
  }

  Future<void> deleteBlock(int index) async {
    final blocks = (chapter!['blocks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final block = blocks[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blok verwijderen?'),
        content: Text(
          'Dit verwijdert "${block['title']}" uit dit hoofdstuk en slaat de wijziging meteen op.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    blocks.removeAt(index);
    for (var i = 0; i < blocks.length; i++) {
      blocks[i]['sort_order'] = i + 1;
    }
    setState(() => selectedBlockIndex = -1);
    await save();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final selected = chapter;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          color: const Color(0xFF20312E),
          child: Row(
            children: [
              const Icon(Icons.construction, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Admin Builder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onClose,
                icon: const Icon(Icons.visibility, color: Colors.white),
                label: const Text(
                  'Leerlingweergave',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(width: 290, child: _sidebar()),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null ? _emptyState() : _editor(selected),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebar() {
    return Container(
      color: const Color(0xFFF7F3EA),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: newChapter,
            icon: const Icon(Icons.add),
            label: const Text('Nieuw hoofdstuk'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: exportExcel,
            icon: const Icon(Icons.download),
            label: const Text('Export Excel'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: importExcel,
            icon: const Icon(Icons.upload_file),
            label: const Text('Import Excel'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: showActivity,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Statistieken'),
          ),
          const SizedBox(height: 14),
          ...chapters.map(
            (item) => Card(
              child: ListTile(
                title: Text(item['title'] as String),
                subtitle: Text(
                  '${item['block_count']} blocks - ${item['status']}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openChapter(item['id'] as String),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: const Text(
          'Kies een hoofdstuk links of maak een nieuw hoofdstuk. Daarna kun je lego-blokjes toevoegen en opslaan.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _editor(Map<String, dynamic> selected) {
    final blocks = (selected['blocks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final activeBlock =
        selectedBlockIndex >= 0 && selectedBlockIndex < blocks.length
        ? blocks[selectedBlockIndex]
        : null;

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Hoofdstuk',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save),
              label: const Text('Opslaan'),
            ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 10),
          Text(message!, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
        const SizedBox(height: 16),
        _chapterFields(selected),
        const SizedBox(height: 22),
        Text('Blokken', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        _blockLibrary(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final blockList = SizedBox(width: 300, child: _blockList(blocks));
            final editor = activeBlock == null
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Selecteer een block.'),
                    ),
                  )
                : BlockEditor(
                    block: activeBlock,
                    onChanged: () => setState(() {}),
                  );

            if (constraints.maxWidth < 980) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: activeBlock == null
                    ? [blockList, const SizedBox(height: 18), editor]
                    : [editor, const SizedBox(height: 18), blockList],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                blockList,
                const SizedBox(width: 24),
                Expanded(child: editor),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _chapterFields(Map<String, dynamic> selected) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _textField(
          'Titel',
          selected['title'],
          (v) => updateChapter('title', v),
          width: 360,
          keySeed: selected['id'],
        ),
        _textField(
          'Subtitel',
          selected['subtitle'],
          (v) => updateChapter('subtitle', v),
          width: 360,
          keySeed: selected['id'],
        ),
        _textField(
          'Slug',
          selected['slug'],
          (v) => updateChapter('slug', v),
          width: 260,
          keySeed: selected['id'],
        ),
        _numberField(
          'Punten (XP)',
          selected['xp'],
          (v) => updateChapter('xp', v),
          width: 140,
          keySeed: selected['id'],
        ),
        _numberField(
          'Hoofdstukpositie',
          selected['sort_order'],
          (v) => updateChapter('sort_order', v),
          width: 170,
          keySeed: selected['id'],
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: selected['status'] as String? ?? 'draft',
            items: const [
              DropdownMenuItem(value: 'draft', child: Text('draft')),
              DropdownMenuItem(value: 'published', child: Text('published')),
              DropdownMenuItem(value: 'archived', child: Text('archived')),
            ],
            onChanged: (value) => updateChapter('status', value ?? 'draft'),
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        _textField(
          'Beschrijving',
          selected['description'],
          (v) => updateChapter('description', v),
          width: 740,
          maxLines: 3,
          keySeed: selected['id'],
        ),
      ],
    );
  }

  Widget _blockLibrary() {
    const types = [
      'hero',
      'text',
      'bible',
      'reading_plan',
      'slider',
      'distribution',
      'multiple_choice',
      'statement_response',
      'deep_dive',
      'reflection',
      'group_discussion',
      'youtube',
      'media_player',
      'audio',
      'gallery',
      'sorting',
      'quote',
      'challenge',
      'upload',
      'personal',
      'prayer',
      'promise',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types
          .map(
            (type) => OutlinedButton.icon(
              onPressed: () => addBlock(type),
              icon: const Icon(Icons.add),
              label: Text(blockTypeLabel(type)),
            ),
          )
          .toList(),
    );
  }

  Widget _blockList(List<Map<String, dynamic>> blocks) {
    return Column(
      children: [
        for (var i = 0; i < blocks.length; i++)
          Card(
            color: selectedBlockIndex == i
                ? const Color(0xFFE9F1EC)
                : Colors.white,
            child: ListTile(
              title: Text(blocks[i]['title'] as String),
              subtitle: Text(
                '${blockTypeLabel(blocks[i]['type'] as String)} - ${blocks[i]['xp']} XP',
              ),
              onTap: () => setState(() => selectedBlockIndex = i),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: () => moveBlock(i, -1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    onPressed: () => moveBlock(i, 1),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    tooltip: 'Verwijderen en opslaan',
                    onPressed: () => deleteBlock(i),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _textField(
    String label,
    dynamic value,
    ValueChanged<String> onChanged, {
    double width = 240,
    int maxLines = 1,
    dynamic keySeed,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('chapter-field-$keySeed-$label'),
        initialValue: '$value',
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberField(
    String label,
    dynamic value,
    ValueChanged<int> onChanged, {
    double width = 120,
    dynamic keySeed,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('chapter-number-$keySeed-$label'),
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (raw) => onChanged(int.tryParse(raw) ?? 0),
      ),
    );
  }
}

class BlockEditor extends StatelessWidget {
  const BlockEditor({super.key, required this.block, required this.onChanged});

  final Map<String, dynamic> block;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final content = block['content'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Block editor', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 18,
              children: [
                _field(
                  'Titel',
                  block['title'],
                  (v) => block['title'] = v,
                  width: 420,
                ),
                _readonlyInfo(
                  'Bloktype',
                  blockTypeLabel(block['type'] as String),
                  width: 220,
                ),
                _num(
                  'Punten (XP)',
                  block['xp'],
                  (v) => block['xp'] = v,
                  width: 150,
                ),
                _num(
                  'Volgorde',
                  block['sort_order'],
                  (v) => block['sort_order'] = v,
                  width: 140,
                ),
                SizedBox(
                  width: 220,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE3DED2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Verplicht')),
                        Switch(
                          value: block['required'] as bool? ?? true,
                          onChanged: (value) {
                            block['required'] = value;
                            onChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 36),
            ..._withSpacing(_contentEditor(context, content)),
          ],
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> widgets) {
    return [
      for (var index = 0; index < widgets.length; index++) ...[
        if (index > 0) const SizedBox(height: 18),
        widgets[index],
      ],
    ];
  }

  List<Widget> _contentEditor(
    BuildContext context,
    Map<String, dynamic> content,
  ) {
    switch (block['type']) {
      case 'hero':
        return [
          _field(
            'Subtitel',
            content['subtitle'] ?? '',
            (v) => content['subtitle'] = v,
            maxLines: 2,
          ),
          _field(
            'Startvraag',
            content['question'] ?? '',
            (v) => content['question'] = v,
            maxLines: 2,
          ),
          _field(
            'Inleidingstekst',
            content['body'] ?? '',
            (v) => content['body'] = v,
            maxLines: 5,
          ),
          _field(
            'Afbeelding URL',
            content['image_url'] ?? '',
            (v) => content['image_url'] = v,
          ),
        ];
      case 'bible':
        return [
          _field(
            'Intro',
            content['intro'],
            (v) => content['intro'] = v,
            maxLines: 3,
          ),
          _field(
            'Referentie',
            content['reference'] ?? '',
            (v) => content['reference'] = v,
          ),
          _listEditor('Vragen', content, 'questions'),
        ];
      case 'reading_plan':
        return [
          _field(
            'Intro',
            content['intro'] ?? '',
            (v) => content['intro'] = v,
            maxLines: 3,
          ),
          _field(
            'Focus van de week',
            content['focus'] ?? '',
            (v) => content['focus'] = v,
            maxLines: 3,
          ),
          _listEditor('Lezingen', content, 'references'),
        ];
      case 'distribution':
        return [
          _field(
            'Prompt',
            content['prompt'],
            (v) => content['prompt'] = v,
            maxLines: 2,
          ),
          _num('Totaal', content['total'], (v) => content['total'] = v),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _switchField(
                'Deel eigen verdeling',
                content['share_with_group'] as bool? ?? true,
                (v) => content['share_with_group'] = v,
              ),
              _switchField(
                'Toon groep na klaar',
                content['show_group_after_submit'] as bool? ?? true,
                (v) => content['show_group_after_submit'] = v,
              ),
            ],
          ),
          _distributionOptions(content),
        ];
      case 'slider':
        return [
          _field(
            'Prompt',
            content['prompt'],
            (v) => content['prompt'] = v,
            maxLines: 2,
          ),
          _field(
            'Min label',
            content['min_label'] ?? '',
            (v) => content['min_label'] = v,
            width: 220,
          ),
          _field(
            'Max label',
            content['max_label'] ?? '',
            (v) => content['max_label'] = v,
            width: 220,
          ),
          _num('Min', content['min'] ?? 0, (v) => content['min'] = v),
          _num('Max', content['max'] ?? 100, (v) => content['max'] = v),
          _num(
            'Default',
            content['default'] ?? 50,
            (v) => content['default'] = v,
          ),
        ];
      case 'multiple_choice':
        return [
          _field(
            'Vraag',
            content['question'] ?? '',
            (v) => content['question'] = v,
            maxLines: 3,
          ),
          _field(
            'Uitleg na antwoord',
            content['explanation'] ?? '',
            (v) => content['explanation'] = v,
            maxLines: 3,
          ),
          _multipleChoiceOptions(content),
        ];
      case 'statement_response':
        return [
          _field(
            'Intro',
            content['intro'] ?? '',
            (v) => content['intro'] = v,
            maxLines: 3,
          ),
          _field(
            'Prompt',
            content['prompt'] ?? '',
            (v) => content['prompt'] = v,
            maxLines: 2,
          ),
          _listEditor('Uitspraken', content, 'statements'),
        ];
      case 'youtube':
      case 'media_player':
      case 'audio':
        return [
          _field(
            'Titel/intro',
            content['intro'] ?? '',
            (v) => content['intro'] = v,
            maxLines: 2,
          ),
          _field('Media URL', content['url'] ?? '', (v) => content['url'] = v),
          _field(
            'Thumbnail URL',
            content['thumbnail_url'] ?? '',
            (v) => content['thumbnail_url'] = v,
          ),
          _listEditor('Kijk-/luistervragen', content, 'questions'),
        ];
      case 'gallery':
        return [
          _field(
            'Prompt',
            content['prompt'] ?? '',
            (v) => content['prompt'] = v,
            maxLines: 2,
          ),
          _listEditor('Afbeelding URLs', content, 'image_urls'),
        ];
      case 'sorting':
        return [
          _field(
            'Prompt',
            content['prompt'] ?? '',
            (v) => content['prompt'] = v,
            maxLines: 2,
          ),
          _listEditor('Categorieen', content, 'categories'),
          _sortingItems(content),
        ];
      case 'quote':
        return [
          _field(
            'Quote',
            content['quote'] ?? '',
            (v) => content['quote'] = v,
            maxLines: 4,
          ),
          _field(
            'Auteur/bron',
            content['source'] ?? '',
            (v) => content['source'] = v,
          ),
        ];
      case 'upload':
        return [
          _field(
            'Prompt',
            content['prompt'] ?? '',
            (v) => content['prompt'] = v,
            maxLines: 3,
          ),
          _listEditor('Toegestane media', content, 'allowed_media'),
        ];
      case 'personal':
      case 'prayer':
        return [
          _field(
            'Prompt',
            content['prompt'] ?? '',
            (v) => content['prompt'] = v,
            maxLines: 3,
          ),
          _field(
            'Placeholder',
            content['placeholder'] ?? '',
            (v) => content['placeholder'] = v,
          ),
        ];
      case 'deep_dive':
        return [
          _field(
            'Samenvatting',
            content['summary'] ?? '',
            (v) => content['summary'] = v,
            maxLines: 3,
          ),
          _field(
            'Callout',
            content['callout'] ?? '',
            (v) => content['callout'] = v,
            maxLines: 2,
          ),
          _sectionsEditor(content),
        ];
      case 'reflection':
        return [
          _field(
            'Prompt',
            content['prompt'],
            (v) => content['prompt'] = v,
            maxLines: 3,
          ),
          _listEditor('Vragen', content, 'questions'),
        ];
      case 'challenge':
        return [
          _field(
            'Prompt',
            content['prompt'] ?? '',
            (v) => content['prompt'] = v,
            maxLines: 3,
          ),
          _num(
            'Min tekens',
            content['min_characters'] ?? 20,
            (v) => content['min_characters'] = v,
          ),
          _listEditor('Voorbeelden', content, 'examples'),
        ];
      case 'group_discussion':
        return [
          _field(
            'Casus/tekst',
            content['case_text'] ?? content['summary'] ?? '',
            (v) => content['case_text'] = v,
            maxLines: 4,
          ),
          _field(
            'Prompt',
            content['prompt'] ?? '',
            (v) => content['prompt'] = v,
            maxLines: 2,
          ),
          _listEditor('Gespreksvragen', content, 'discussion_questions'),
        ];
      case 'promise':
        return [
          _field(
            'Intro',
            content['intro'] ?? '',
            (v) => content['intro'] = v,
            maxLines: 2,
          ),
          _num(
            'Minimum tekens',
            content['min_characters'] ?? 25,
            (v) => content['min_characters'] = v,
            width: 180,
          ),
          _listEditor('Prompts', content, 'prompts'),
        ];
      default:
        return [
          _field(
            'Tekst',
            content['body'] ?? content['summary'] ?? '',
            (v) => content['body'] = v,
            maxLines: 6,
          ),
          _field('URL', content['url'] ?? '', (v) => content['url'] = v),
          _field(
            'Knoptekst',
            content['link_label'] ?? '',
            (v) => content['link_label'] = v,
          ),
          _listEditor('Vragen', content, 'questions'),
        ];
    }
  }

  Widget _sectionsEditor(Map<String, dynamic> content) {
    final sections = (content['sections'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    content['sections'] = sections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rowTitle('Verdiepings-tiles', () {
          sections.add({'title': 'Nieuwe verdieping', 'body': ''});
          onChanged();
        }),
        for (var i = 0; i < sections.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _field(
                    'Titel',
                    sections[i]['title'],
                    (v) => sections[i]['title'] = v,
                  ),
                  const SizedBox(height: 8),
                  _field(
                    'Inhoud',
                    sections[i]['body'],
                    (v) => sections[i]['body'] = v,
                    maxLines: 5,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _distributionOptions(Map<String, dynamic> content) {
    final options = (content['options'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    content['options'] = options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rowTitle('Verdeling opties', () {
          final next = options.length + 1;
          options.add({
            'id': 'optie_$next',
            'label': 'Optie $next',
            'description': '',
            'default': 0,
          });
          onChanged();
        }),
        for (final option in options)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  _field(
                    'Naam',
                    option['label'],
                    (v) => option['label'] = v,
                    width: 240,
                  ),
                  _field(
                    'Omschrijving',
                    option['description'],
                    (v) => option['description'] = v,
                    width: 360,
                  ),
                  _num(
                    'Default',
                    option['default'],
                    (v) => option['default'] = v,
                    width: 140,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _multipleChoiceOptions(Map<String, dynamic> content) {
    final options = (content['options'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    content['options'] = options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rowTitle('Antwoorden', () {
          final next = options.length + 1;
          options.add({
            'id': 'optie_$next',
            'text': 'Optie $next',
            'is_correct': false,
          });
          onChanged();
        }),
        for (final option in options)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _field(
                    'Antwoord',
                    option['text'],
                    (v) => option['text'] = v,
                    width: 420,
                  ),
                  SizedBox(
                    width: 180,
                    child: SwitchListTile(
                      value: option['is_correct'] as bool? ?? false,
                      title: const Text('Correct'),
                      onChanged: (value) {
                        option['is_correct'] = value;
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sortingItems(Map<String, dynamic> content) {
    final items = (content['items'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    content['items'] = items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rowTitle('Sorteer-items', () {
          items.add({'text': 'Nieuw item', 'category': ''});
          onChanged();
        }),
        for (final item in items)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  _field(
                    'Item',
                    item['text'],
                    (v) => item['text'] = v,
                    width: 320,
                  ),
                  _field(
                    'Categorie',
                    item['category'],
                    (v) => item['category'] = v,
                    width: 260,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _listEditor(String title, Map<String, dynamic> content, String key) {
    final values = (content[key] as List<dynamic>? ?? <dynamic>[])
        .map((item) => '$item')
        .toList();
    content[key] = values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rowTitle(title, () {
          values.add('');
          onChanged();
        }),
        for (var i = 0; i < values.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _field(
              '$title ${i + 1}',
              values[i],
              (v) => values[i] = v,
              maxLines: 2,
            ),
          ),
      ],
    );
  }

  Widget _rowTitle(String title, VoidCallback onAdd) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Toevoegen'),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    dynamic value,
    ValueChanged<String> onValue, {
    double width = double.infinity,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('block-field-${block['id']}-$label'),
        initialValue: '${value ?? ''}',
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onChanged: (value) {
          onValue(value);
          onChanged();
        },
      ),
    );
  }

  Widget _num(
    String label,
    dynamic value,
    ValueChanged<int> onValue, {
    double width = 120,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('block-number-${block['id']}-$label'),
        initialValue: '${value ?? 0}',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onChanged: (raw) {
          onValue(int.tryParse(raw) ?? 0);
          onChanged();
        },
      ),
    );
  }

  Widget _readonlyInfo(String label, String value, {double width = 220}) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _switchField(String label, bool value, ValueChanged<bool> onValue) {
    return SizedBox(
      width: 250,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE3DED2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Switch(
              value: value,
              onChanged: (next) {
                onValue(next);
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> defaultBlock(String type, String chapterId, int order) {
  final id = '${chapterId}_${type}_$order';
  return {
    'id': id,
    'chapter_id': chapterId,
    'type': type,
    'title': defaultTitle(type),
    'xp': type == 'hero' ? 0 : 10,
    'required': true,
    'sort_order': order,
    'content': defaultContent(type),
  };
}

String defaultTitle(String type) {
  return switch (type) {
    'hero' => 'Nieuwe inleiding',
    'bible' => 'Bijbelgedeelte',
    'reading_plan' => 'Leesrooster',
    'distribution' => 'Verdeelvraag',
    'statement_response' => 'Dooddoeners',
    'deep_dive' => 'Verdieping',
    'reflection' => 'Reflectie',
    'group_discussion' => 'Groepsgesprek',
    'challenge' => 'Challenge',
    'promise' => 'Wat neem je mee?',
    _ => 'Tekstblok',
  };
}

String blockTypeLabel(String type) {
  return switch (type) {
    'hero' => 'Inleiding',
    'text' => 'Tekst',
    'bible' => 'Bijbel',
    'reading_plan' => 'Leesrooster',
    'slider' => 'Schuifvraag',
    'distribution' => 'Verdeelvraag',
    'multiple_choice' => 'Meerkeuze',
    'statement_response' => 'Dooddoeners',
    'deep_dive' => 'Verdieping',
    'reflection' => 'Reflectie',
    'group_discussion' => 'Groepsgesprek',
    'youtube' => 'YouTube',
    'media_player' => 'Mediaplayer',
    'audio' => 'Audio',
    'gallery' => 'Galerij',
    'sorting' => 'Sorteervraag',
    'quote' => 'Quote',
    'challenge' => 'Challenge',
    'upload' => 'Upload',
    'personal' => 'Persoonlijk',
    'prayer' => 'Gebed',
    'promise' => 'Wat neem je mee?',
    _ => type,
  };
}

Map<String, dynamic> defaultContent(String type) {
  return switch (type) {
    'bible' => {
      'reference': 'Johannes 1:1-18',
      'intro': '',
      'questions': <String>[],
    },
    'reading_plan' => {
      'intro': 'Lees deze gedeelten door in de week.',
      'focus':
          'Let erop hoe de lezingen samen het thema van deze week uitwerken.',
      'references': [
        'Psalm 1',
        'Psalm 2',
        'Psalm 3',
        'Psalm 4',
        'Psalm 5',
        'Psalm 6',
        'Psalm 7',
      ],
    },
    'slider' => {
      'prompt': 'Schuif naar wat het beste past.',
      'min': 0,
      'max': 100,
      'default': 50,
      'min_label': 'Links',
      'max_label': 'Rechts',
    },
    'distribution' => {
      'prompt': 'Verdeel 100 procent.',
      'total': 100,
      'unit': '%',
      'step': 5,
      'share_with_group': true,
      'show_group_after_submit': true,
      'options': [
        {'id': 'optie_1', 'label': 'Optie 1', 'description': '', 'default': 50},
        {'id': 'optie_2', 'label': 'Optie 2', 'description': '', 'default': 50},
      ],
    },
    'multiple_choice' => {
      'question': 'Nieuwe meerkeuzevraag',
      'options': [
        {'id': 'a', 'text': 'Antwoord A', 'is_correct': true},
        {'id': 'b', 'text': 'Antwoord B', 'is_correct': false},
      ],
      'explanation': '',
    },
    'statement_response' => {
      'intro': 'Kies een uitspraak en reageer erop.',
      'prompt': 'Welke dooddoener wil jij nuanceren of tegenspreken?',
      'statements': [
        'Dat zal dan wel Gods bedoeling zijn.',
        'Je moet er gewoon niet te veel over nadenken.',
        'Als je genoeg gelooft, komt het vanzelf goed.',
      ],
    },
    'deep_dive' => {
      'summary': '',
      'sections': [
        {'title': 'Nieuwe verdieping', 'body': ''},
      ],
    },
    'reflection' => {
      'prompt': '',
      'placeholder': 'Schrijf je gedachte op...',
      'visibility': 'private',
    },
    'youtube' => {
      'url': '',
      'intro': '',
      'thumbnail_url': '',
      'questions': <String>[],
    },
    'media_player' => {
      'url': '',
      'intro': '',
      'thumbnail_url': '',
      'questions': <String>[],
    },
    'audio' => {'url': '', 'intro': '', 'questions': <String>[]},
    'gallery' => {'prompt': '', 'image_urls': <String>[]},
    'sorting' => {
      'prompt': 'Sleep of kies de juiste categorie.',
      'categories': <String>['Categorie 1', 'Categorie 2'],
      'items': [
        {'text': 'Item 1', 'category': 'Categorie 1'},
      ],
    },
    'quote' => {'quote': '', 'source': ''},
    'upload' => {
      'prompt': '',
      'allowed_media': <String>['image'],
    },
    'personal' => {
      'prompt': '',
      'placeholder': 'Schrijf persoonlijk...',
      'visibility': 'private',
    },
    'prayer' => {'prompt': '', 'placeholder': 'Schrijf je gebed...'},
    'group_discussion' => {'prompt': '', 'discussion_questions': <String>[]},
    'challenge' => {
      'prompt': 'Kies een concrete actie en deel wat je gaat doen.',
      'min_characters': 20,
      'examples': <String>['Voorbeeldactie'],
    },
    'promise' => {
      'intro':
          'Schrijf per vraag een echte zin. Je antwoord verschijnt op het groepsbord.',
      'min_characters': 25,
      'prompts': <String>['Wat heb ik geleerd?'],
    },
    'hero' => {'subtitle': '', 'question': '', 'body': ''},
    _ => {'body': '', 'questions': <String>[]},
  };
}
