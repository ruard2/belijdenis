/// Zet een YouTube- of Vimeo-link om naar een embed-URL, of null als dat niet kan.
String? videoEmbedUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  String? youtubeId;
  if (host.endsWith('youtu.be')) {
    youtubeId = segments.isNotEmpty ? segments.first : null;
  } else if (host.contains('youtube.com') ||
      host.contains('youtube-nocookie.com')) {
    youtubeId = uri.queryParameters['v'];
    for (final marker in ['embed', 'shorts', 'live', 'v']) {
      final index = segments.indexOf(marker);
      if (youtubeId == null && index >= 0 && segments.length > index + 1) {
        youtubeId = segments[index + 1];
      }
    }
  }
  if (youtubeId != null && RegExp(r'^[\w-]{6,}$').hasMatch(youtubeId)) {
    final start = uri.queryParameters['t'] ?? uri.queryParameters['start'];
    final seconds = int.tryParse((start ?? '').replaceAll('s', ''));
    return 'https://www.youtube.com/embed/$youtubeId'
        '${seconds != null && seconds > 0 ? '?start=$seconds' : ''}';
  }

  if (host.contains('vimeo.com')) {
    final id = segments.lastWhere(
      (s) => RegExp(r'^\d+$').hasMatch(s),
      orElse: () => '',
    );
    if (id.isNotEmpty) return 'https://player.vimeo.com/video/$id';
  }
  return null;
}

bool isEmbeddableVideo(String url) => videoEmbedUrl(url) != null;
