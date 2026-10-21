import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/community_models.dart';
import '../providers/community_provider.dart';
import 'community_post_detail_screen.dart';

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  final List<String> _tags = const [
    'All',
    'Mastitis & Udder',
    'Breeding & Infertility',
    'Skin & Lumpy',
    'Bloat & Digestion',
    'Calfhood & Nutrition',
  ];

  @override
  Widget build(BuildContext context) {
    final selectedTag = ref.watch(selectedCommunityTagProvider);
    final postsAsync = ref.watch(communityPostsProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cattle Health Community',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Ask Farmers & Certified Bovine Vets',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Feed',
            onPressed: () => ref.invalidate(communityPostsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleCreatePost(context, isAuthenticated),
        backgroundColor: const Color(0xff047857),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Ask / Post Cattle Photo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
          // Filter Tags Bar
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tags.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = _tags[index];
                final isSelected = tag == selectedTag;
                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  selectedColor: const Color(0xffecfdf5),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xff047857) : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected ? const Color(0xff10b981) : Colors.grey.shade300,
                  ),
                  onSelected: (val) {
                    if (val) {
                      ref.read(selectedCommunityTagProvider.notifier).state = tag;
                    }
                  },
                );
              },
            ),
          ),

          // Posts Feed
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error loading community cases: $err', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(communityPostsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.forum_outlined, size: 56, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'No community questions in this category yet.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Be the first farmer to share a case or ask our certified veterinarians for advice.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _handleCreatePost(context, isAuthenticated),
                            icon: const Icon(Icons.add_a_photo),
                            label: const Text('Post First Case'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xff047857)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _CommunityPostCard(post: post);
                  },
                );
              },
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _handleCreatePost(BuildContext context, bool isAuthenticated) {
    if (!isAuthenticated) {
      _showLoginRequiredSheet(context);
    } else {
      _showCreatePostSheet(context);
    }
  }

  void _showLoginRequiredSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_outline, color: Color(0xff047857)),
                  SizedBox(width: 8),
                  Text(
                    'Sign In to Post Question',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to link your dairy farm profile and ask our verified veterinary doctors and fellow dairy farmers for advice.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              const Text(
                '1-Click Demo Account Sign In:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff047857)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(authProvider.notifier).loginWithPassword('9876510001', 'Password@123');
                      if (context.mounted) _showCreatePostSheet(context);
                    },
                    child: const Text('🌾 Ramesh Patel'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(authProvider.notifier).loginWithPassword('9876510002', 'Password@123');
                      if (context.mounted) _showCreatePostSheet(context);
                    },
                    child: const Text('🐃 Suresh Yadav'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(authProvider.notifier).loginWithPassword('9825099001', 'Password@123');
                      if (context.mounted) _showCreatePostSheet(context);
                    },
                    child: const Text('👨‍⚕️ Dr. Hasmukh Deshmukh (Vet)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/login?next=/community');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In with Phone / Password'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xff047857)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final cattleTagCtrl = TextEditingController();
    final imgUrlCtrl = TextEditingController();
    String selectedTag = 'Mastitis & Udder';
    bool isPosting = false;

    // Preset high quality sample cattle photos
    final samplePhotos = [
      'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800',
      'https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=800',
      'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=800',
      'https://images.unsplash.com/photo-1563281577-a7be47e20db9?w=800',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ask Question / Share Case',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Question Title / Problem Summary',
                        hintText: 'e.g. Swelling in rear teat, cow stopped eating',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedTag,
                      decoration: const InputDecoration(
                        labelText: 'Issue Category',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _tags.where((t) => t != 'All').map((t) {
                        return DropdownMenuItem(value: t, child: Text(t));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedTag = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cattleTagCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cattle Tag / Name (Optional)',
                        hintText: 'e.g. Gir Cow #GIR-0104',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Describe the issue in detail',
                        hintText: 'Mention symptoms, rectal temperature, rumination, milk yield drop, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Attach Cattle Photo:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 64,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: samplePhotos.length,
                        itemBuilder: (ctx, idx) {
                          final pUrl = samplePhotos[idx];
                          final isPicked = imgUrlCtrl.text == pUrl;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() => imgUrlCtrl.text = pUrl);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isPicked ? const Color(0xff047857) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(pUrl, width: 64, height: 64, fit: BoxFit.cover),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: imgUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Or paste image URL',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isPosting
                            ? null
                            : () async {
                                final title = titleCtrl.text.trim();
                                final desc = descCtrl.text.trim();
                                if (title.isEmpty || desc.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter title and description')),
                                  );
                                  return;
                                }

                                setModalState(() => isPosting = true);
                                try {
                                  final images = imgUrlCtrl.text.trim().isNotEmpty
                                      ? [imgUrlCtrl.text.trim()]
                                      : [samplePhotos[0]];

                                  await createCommunityPost(
                                    ref,
                                    title: title,
                                    description: desc,
                                    issueTag: selectedTag,
                                    cattleTag: cattleTagCtrl.text.trim().isNotEmpty
                                        ? cattleTagCtrl.text.trim()
                                        : null,
                                    imageUrls: images,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Question published to community & veterinarians!'),
                                        backgroundColor: Color(0xff047857),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isPosting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to publish: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff047857),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isPosting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Publish Case to Community', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CommunityPostCard extends ConsumerWidget {
  final CommunityPost post;
  const _CommunityPostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CommunityPostDetailScreen(postId: post.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xffecfdf5),
                    child: Text(
                      post.authorName.isNotEmpty ? post.authorName[0] : 'F',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff047857)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: post.authorRole == 'vet'
                                    ? const Color(0xffecfdf5)
                                    : const Color(0xfff1f5f9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                post.authorRole == 'vet' ? '🩺 Vet Doctor' : '🌾 Dairy Farmer',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: post.authorRole == 'vet'
                                      ? const Color(0xff047857)
                                      : const Color(0xff475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _timeAgo(post.createdAt),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            if (post.cattleTag != null) ...[
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 8),
                              Text(
                                'Tag: ${post.cattleTag}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xff047857)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              const SizedBox(height: 12),

              // Title and Description
              Text(
                post.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                post.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
              ),
              const SizedBox(height: 12),

              // Cattle image if available
              if (post.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    post.imageUrls.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 12),

              // Action buttons (Like, Comments, View Advice)
              Row(
                children: [
                  InkWell(
                    onTap: () => likeCommunityPost(ref, postId: post.id),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_border, size: 18, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('${post.likesCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xff047857)),
                      const SizedBox(width: 4),
                      Text('${post.commentsCount} Advice', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Read Advice >',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
