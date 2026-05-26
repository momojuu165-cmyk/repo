import 'dart:io';
import 'package:flutter/material.dart';

/// Returns a widget that shows an image whether the path is a local file or a remote URL.
/// Falls back to [fallback] if loading fails or path is null/empty.
Widget buildProductImage(
  String? path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
  Widget? fallback,
}) {
  final placeholder = fallback ??
      Container(
        width: width,
        height: height,
        color: Colors.grey.shade100,
        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      );

  if (path == null || path.isEmpty) return placeholder;

  final isUrl = path.startsWith('http://') || path.startsWith('https://');
  final Widget img;

  if (isUrl) {
    img = Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  } else {
    final file = File(path);
    if (!file.existsSync()) return placeholder;
    img = Image.file(file, width: width, height: height, fit: fit,
        errorBuilder: (_, __, ___) => placeholder);
  }

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: img);
  }
  return img;
}
