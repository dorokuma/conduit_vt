import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:quiver/collection.dart';

/// A cache of laid out [Paragraph]s. This is used to avoid laying out the same
/// text multiple times, which is expensive.
class ParagraphCache {
  ParagraphCache(this.maximumSize)
    : _cache = LruMap<int, Paragraph>(maximumSize: maximumSize);

  /// Maximum number of cached layouts. Evicted paragraphs are disposed.
  final int maximumSize;

  final LruMap<int, Paragraph> _cache;

  /// Returns a [Paragraph] for the given [key]. [key] is the same as the
  /// key argument to [performAndCacheLayout].
  Paragraph? getLayoutFromCache(int key) {
    return _cache[key];
  }

  /// Applies [style] and [textScaler] to [text] and lays it out to create
  /// a [Paragraph]. The [Paragraph] is cached and can be retrieved with the
  /// same [key] by calling [getLayoutFromCache].
  Paragraph performAndCacheLayout(
    String text,
    TextStyle style,
    TextScaler textScaler,
    int key,
  ) {
    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(style.getTextStyle(textScaler: textScaler));
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    if (!_cache.containsKey(key) &&
        maximumSize > 0 &&
        _cache.length >= maximumSize) {
      // Disposing the evicted paragraph frees the native layout object.
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey)?.dispose();
    }

    _cache[key] = paragraph;
    return paragraph;
  }

  /// Clears the cache. This should be called when the same text and style
  /// pair no longer produces the same layout. For example, when a font is
  /// loaded.
  void clear() {
    for (final paragraph in _cache.values.toList(growable: false)) {
      paragraph.dispose();
    }
    _cache.clear();
  }

  /// Returns the number of [Paragraph]s in the cache.
  int get length {
    return _cache.length;
  }
}
