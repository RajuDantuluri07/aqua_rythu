import '../../models/feed_model.dart';

abstract class FeedRepository {
  Future<List<FeedEntry>> getFeeds(String pondId);
  Future<void> addFeed(String pondId, FeedEntry entry);
}

class LocalFeedRepository implements FeedRepository {
  final Map<String, List<FeedEntry>> _storage = {};

  @override
  Future<List<FeedEntry>> getFeeds(String pondId) async {
    return _storage[pondId] ?? [];
  }

  @override
  Future<void> addFeed(String pondId, FeedEntry entry) async {
    _storage.putIfAbsent(pondId, () => []);
    _storage[pondId]!.add(entry);
  }
}