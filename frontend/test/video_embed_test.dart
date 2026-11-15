import 'package:flutter_test/flutter_test.dart';
import 'package:houvast_frontend/video_embed.dart';

void main() {
  test('YouTube- en Vimeo-links worden embed-URLs', () {
    const id = 'eAvYmE2YYIU';
    for (final url in [
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id&list=abc',
      'https://m.youtube.com/watch?v=$id',
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=xyz',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/live/$id?feature=share',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube-nocookie.com/embed/$id',
    ]) {
      expect(videoEmbedUrl(url), 'https://www.youtube.com/embed/$id', reason: url);
    }
    expect(
      videoEmbedUrl('https://youtu.be/$id?t=90'),
      'https://www.youtube.com/embed/$id?start=90',
    );
    expect(
      videoEmbedUrl('https://vimeo.com/123456789'),
      'https://player.vimeo.com/video/123456789',
    );
    expect(videoEmbedUrl('https://www.desiringgod.org/messages/x'), isNull);
    expect(videoEmbedUrl('geen url'), isNull);
  });
}
