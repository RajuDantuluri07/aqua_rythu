abstract class FeedRepository {
  Future<List<Map<String, dynamic>>> getFeeds(String pondId);
  Future<void> addFeed(String pondId, Map<String, dynamic> entry);
}

class LocalFeedRepository implements FeedRepository {
  final Map<String, List<Map<String, dynamic>>> _storage = {};

  @override
  Future<List<Map<String, dynamic>>> getFeeds(String pondId) async {
    return _storage[pondId] ?? [];
  }

  @override
  Future<void> addFeed(String pondId, Map<String, dynamic> entry) async {
    _storage.putIfAbsent(pondId, () => []);
    _storage[pondId]!.add(entry);
  }
}
