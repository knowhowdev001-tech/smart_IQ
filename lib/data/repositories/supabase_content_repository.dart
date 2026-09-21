import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/content.dart';
import 'repositories.dart';
import 'supabase_guard.dart';

/// Catalogue and published content, read through the catalogue RPCs.
///
/// These are RPCs rather than table reads because each one carries counts and
/// the caller's own mastery, which a plain select could not assemble without
/// exposing rows the client is not allowed to see (PRD 9.4).
// ignore_for_file: prefer_initializing_formals

class SupabaseContentRepository implements ContentRepository {
  SupabaseContentRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  /// The catalogue is fixed configuration, so the key-to-id map is fetched
  /// once per app run. The RPCs take a category uuid while every screen
  /// works in keys, and this is the only place that gap is bridged.
  Map<String, String>? _categoryIds;

  @override
  Future<List<Category>> categories() async {
    final rows = await supabaseGuard(
      () => _client.rpc<dynamic>('get_categories'),
    );
    final categories = [
      for (final row in (rows as List? ?? const []))
        Category.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
    _categoryIds = {for (final c in categories) c.key: c.id};
    return categories;
  }

  /// The category uuid behind a key, or null when the key is not a real
  /// category — `mock`, for instance, which the practice screen uses to mean
  /// "the whole bank".
  Future<String?> categoryId(String key) async {
    if (_categoryIds == null) await categories();
    return _categoryIds?[key];
  }

  @override
  Future<List<SubTopic>> subTopics(String categoryKey) async {
    final id = await categoryId(categoryKey);
    final rows = await supabaseGuard(
      () => _client.rpc<dynamic>('get_sub_topics', params: {
        'p_category_id': id,
      }),
    );
    return [
      for (final row in (rows as List? ?? const []))
        SubTopic.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<List<CurrentAffairsItem>> currentAffairs() async {
    final rows = await supabaseGuard(
      () => _client.rpc<dynamic>('get_current_affairs', params: {
        'p_limit': 20,
      }),
    );
    return [
      for (final row in (rows as List? ?? const []))
        CurrentAffairsItem.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Media columns hold Storage object paths, never URLs, so that the bucket
  /// or the host can change without a data migration (PRD 9.3).
  @override
  String mediaUrl(String path) {
    // Vector art the app draws itself; there is nothing to fetch.
    if (path.startsWith('builtin:')) return path;
    return _client.storage.from(_mediaBucket).getPublicUrl(path);
  }

  static const _mediaBucket = 'question-media';
}
