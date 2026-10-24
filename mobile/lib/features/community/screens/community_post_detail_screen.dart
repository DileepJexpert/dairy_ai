import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/community_models.dart';
import '../providers/community_provider.dart';

class CommunityPostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const CommunityPostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<CommunityPostDetailScreen> createState() => _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends ConsumerState<CommunityPostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(communityPostDetailProvider(widget.postId));
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );
    final currentUser = authState.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cattle Case Discussion'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(communityPostDetailProvider(widget.postId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: $err', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(communityPostDetailProvider(widget.postId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final post = CommunityPost.fromJson(data);
          final rawComments = (data['comments'] as List<dynamic>?) ?? [];
          final comments = rawComments.map((c) => CommunityComment.fromJson(c as Map<String, dynamic>)).toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Post Author & Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xffecfdf5),
                          child: Text(
                            post.authorName.isNotEmpty ? post.authorName[0] : 'F',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff047857), fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Row(
                                children: [
                                  Text(
                                    post.authorRole == 'vet' ? '🩺 Vet Doctor' : '🌾 Dairy Farmer',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: post.authorRole == 'vet' ? const Color(0xff047857) : Colors.grey.shade700,
                                    ),
                                  ),
                                  if (post.cattleTag != null) ...[
                                    const SizedBox(width: 6),
                                    const Text('•', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Cattle: ${post.cattleTag}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff047857)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xffecfdf5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffa7f3d0)),
                          ),
                          child: Text(
                            post.issueTag,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff065f46)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      post.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Description
                    Text(
                      post.description,
                      style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),

                    // Cattle Photo gallery
                    if (post.imageUrls.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          post.imageUrls.first,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Likes bar
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => likeCommunityPost(ref, postId: post.id),
                          icon: const Icon(Icons.favorite, size: 16, color: Colors.red),
                          label: Text('${post.likesCount} Helpful'),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${comments.length} Doctor & Farmer Suggestions',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Comments & Doctor Advisory Header
                    const Row(
                      children: [
                        Icon(Icons.question_answer_outlined, color: Color(0xff047857), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Doctor Advice & Farmer Community',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No advice added yet. Be the first to share suggestions.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...comments.map((comm) => _buildCommentTile(comm)),
                  ],
                ),
              ),

              // Bottom Comment Input Bar
              _buildBottomCommentBar(context, isAuthenticated, currentUser),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommentTile(CommunityComment comm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: comm.isVerifiedVet ? const Color(0xfff0fdf4) : const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: comm.isVerifiedVet ? const Color(0xff86efac) : const Color(0xffe2e8f0),
          width: comm.isVerifiedVet ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: comm.isVerifiedVet ? const Color(0xff047857) : Colors.grey.shade300,
                child: Icon(
                  comm.isVerifiedVet ? Icons.medical_services : Icons.person,
                  size: 16,
                  color: comm.isVerifiedVet ? Colors.white : Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comm.authorName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (comm.isVerifiedVet) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xff047857),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 10, color: Colors.white),
                                SizedBox(width: 2),
                                Text(
                                  'Verified Doctor',
                                  style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (comm.isVerifiedVet && comm.vetQualification != null)
                      Text(
                        '${comm.vetQualification!} • ${comm.vetClinic ?? 'Veterinarian'}',
                        style: const TextStyle(fontSize: 10, color: Color(0xff047857), fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comm.comment,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: comm.isVerifiedVet ? const Color(0xff064e3b) : Colors.black87,
              fontWeight: comm.isVerifiedVet ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCommentBar(BuildContext context, bool isAuthenticated, dynamic currentUser) {
    final isDoctor = currentUser?.role == 'vet';

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: isDoctor
                    ? 'Write clinical recommendation as Verified Doctor...'
                    : 'Suggest home remedy or share experience...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : () => _handleSendComment(context, isAuthenticated),
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            style: IconButton.styleFrom(backgroundColor: const Color(0xff047857)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendComment(BuildContext context, bool isAuthenticated) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!isAuthenticated) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign In to Post Advice'),
          content: const Text('Please sign in to comment and advise on this cattle case.'),
          actions: [
            if (kDebugMode || AppConstants.flowSimulation) ...[
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authProvider.notifier).loginWithPassword('9825099001', 'Password@123');
                },
                child: const Text('👨‍⚕️ Login as Dr. Deshmukh (Vet)'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authProvider.notifier).loginWithPassword('9876510001', 'Password@123');
                },
                child: const Text('🌾 Login as Ramesh (Farmer)'),
              ),
            ],
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/login?next=/community');
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await addCommunityComment(ref, postId: widget.postId, comment: text);
      _commentController.clear();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post advice: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
