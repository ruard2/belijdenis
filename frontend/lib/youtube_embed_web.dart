import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredYoutubeViews = {};

Widget buildYoutubeEmbed(String url) {
  final embedUrl = _toEmbedUrl(url);
  final viewType = 'youtube-${embedUrl.hashCode}';

  if (_registeredYoutubeViews.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return web.HTMLIFrameElement()
        ..src = embedUrl
        ..style.border = '0'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = true;
    });
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: HtmlElementView(viewType: viewType),
    ),
  );
}

String _toEmbedUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  String? videoId;
  if (uri.host.contains('youtu.be')) {
    videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  } else if (uri.host.contains('youtube.com')) {
    videoId = uri.queryParameters['v'];
    if (videoId == null && uri.pathSegments.contains('embed')) {
      final index = uri.pathSegments.indexOf('embed');
      if (uri.pathSegments.length > index + 1) {
        videoId = uri.pathSegments[index + 1];
      }
    }
  }

  if (videoId == null || videoId.isEmpty) return url;
  return 'https://www.youtube.com/embed/$videoId';
}
