import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'video_embed.dart';

final Set<String> _registeredYoutubeViews = {};

Widget buildYoutubeEmbed(String url) {
  final embedUrl = videoEmbedUrl(url) ?? url;
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
