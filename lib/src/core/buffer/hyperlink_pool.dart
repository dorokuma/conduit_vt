/// A pool that stores and deduplicates URI strings for OSC 8 hyperlinks.
///
/// Hyperlink IDs are positive integers (starting from 1). ID 0 represents
/// the absence of a hyperlink.
///
/// Note on release / lifetime:
/// This pool is append-only for simplicity and performance. IDs are retained
/// across the terminal session, deduplicating identical URIs into the same ID.
class HyperlinkPool {
  final Map<String, int> _uriToId = {};
  final List<String> _idToUri = [''];

  /// Acquires an ID for the given [uri]. If [uri] was previously registered,
  /// returns the existing ID; otherwise, assigns a new ID.
  int acquire(String uri) {
    final existing = _uriToId[uri];
    if (existing != null) {
      return existing;
    }
    final id = _idToUri.length;
    _uriToId[uri] = id;
    _idToUri.add(uri);
    return id;
  }

  /// Returns the URI associated with [id], or `null` if [id] is invalid or 0.
  String? get(int id) {
    if (id <= 0 || id >= _idToUri.length) {
      return null;
    }
    return _idToUri[id];
  }

  /// Number of registered hyperlinks in the pool.
  int get size => _idToUri.length - 1;
}
