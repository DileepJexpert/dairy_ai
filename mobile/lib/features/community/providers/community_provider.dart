import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/community_models.dart';

final selectedCommunityTagProvider = StateProvider<String>((ref) => 'All');

final communityPostsProvider = FutureProvider.autoDispose<List<CommunityPost>>((ref) async {
  final dio = ref.watch(dioProvider);
  final tag = ref.watch(selectedCommunityTagProvider);

  final response = await dio.get(
    '/community/posts',
    queryParameters: tag != 'All' ? {'tag': tag} : null,
  );

  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  return [];
});

final communityPostDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, postId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/community/posts/$postId');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return body['data'] as Map<String, dynamic>;
  }
  throw Exception(body['message'] ?? 'Failed to load post details');
});

Future<void> createCommunityPost(
  WidgetRef ref, {
  required String title,
  required String description,
  required String issueTag,
  String? cattleTag,
  List<String> imageUrls = const [],
}) async {
  final dio = ref.read(dioProvider);
  await dio.post('/community/posts', data: {
    'title': title,
    'description': description,
    'issue_tag': issueTag,
    'cattle_tag': cattleTag,
    'image_urls': imageUrls,
  });
  ref.invalidate(communityPostsProvider);
}

Future<void> addCommunityComment(
  WidgetRef ref, {
  required String postId,
  required String comment,
}) async {
  final dio = ref.read(dioProvider);
  await dio.post('/community/posts/$postId/comments', data: {
    'comment': comment,
  });
  ref.invalidate(communityPostDetailProvider(postId));
  ref.invalidate(communityPostsProvider);
}

Future<void> likeCommunityPost(
  WidgetRef ref, {
  required String postId,
}) async {
  final dio = ref.read(dioProvider);
  await dio.post('/community/posts/$postId/like');
  ref.invalidate(communityPostDetailProvider(postId));
  ref.invalidate(communityPostsProvider);
}
