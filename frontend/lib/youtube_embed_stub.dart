import 'package:flutter/material.dart';

Widget buildYoutubeEmbed(String url) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF20312E),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'YouTube video',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      textAlign: TextAlign.center,
    ),
  );
}
