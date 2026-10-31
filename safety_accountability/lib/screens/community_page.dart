import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/community_service.dart';
import '../widgets/user_profile_sheet.dart';
import '../widgets/video_viewer.dart';

const List<String> _categoryLabels = [
  'General Alert',
  'Stolen Vehicle',
  'Break-In',
  'Missing Person',
  'Wanted Person',
  'Suspicious Activity',
  'Stolen Goods',
  'Vandalism',
];

const Map<String, String> _categoryValues = {
  'General Alert': 'general_alert',
  'Stolen Vehicle': 'stolen_vehicle',
  'Break-In': 'break_in',
  'Missing Person': 'missing_person',
  'Wanted Person': 'wanted_person',
  'Suspicious Activity': 'suspicious_activity',
  'Stolen Goods': 'stolen_goods',
  'Vandalism': 'vandalism',
};

const Map<String, String> _reportReasons = {
  'False information': 'false_information',
  'Harassment or abuse': 'harassment',
  'Spam': 'spam',
  'Inappropriate content': 'inappropriate',
  'Other': 'other',
};

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class PostMediaItem {
  final int id;
  final String url;
  final String mediaType; // image, video

  PostMediaItem({required this.id, required this.url, required this.mediaType});

  factory PostMediaItem.fromJson(Map<String, dynamic> json) => PostMediaItem(
        id: json['id'] as int,
        url: json['file']?.toString() ?? '',
        mediaType: json['media_type']?.toString() ?? 'image',
      );
}

class CommunityPost {
  final int id;
  final int? authorId;
  final String? authorPhoto;
  final String authorName;
  final String authorAvatar;
  final String postType;
  final String category;
  final String categoryDisplay;
  final String content;
  final String locationDescription;
  final bool isOfficial;
  final bool isQuickAlert;
  final DateTime createdAt;
  int likesCount;
  int commentsCount;
  int sharesCount;
  final bool isTrending;
  final double? distanceKm;
  bool likedByMe;
  final List<PostMediaItem> media;

  CommunityPost({
    required this.id,
    this.authorId,
    this.authorPhoto,
    required this.authorName,
    required this.authorAvatar,
    required this.postType,
    required this.category,
    required this.categoryDisplay,
    required this.content,
    required this.locationDescription,
    required this.isOfficial,
    required this.isQuickAlert,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isTrending,
    required this.distanceKm,
    required this.likedByMe,
    required this.media,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
        id: json['id'] as int,
        authorId: (json['author_id'] as num?)?.toInt(),
        authorPhoto: json['author_photo']?.toString(),
        authorName: json['author_name']?.toString() ?? 'Unknown',
        authorAvatar: json['author_avatar']?.toString() ?? '?',
        postType: json['post_type']?.toString() ?? 'alert',
        category: json['category']?.toString() ?? 'general_alert',
        categoryDisplay: json['category_display']?.toString() ?? 'General Alert',
        content: json['content']?.toString() ?? '',
        locationDescription: json['location_description']?.toString() ?? '',
        isOfficial: json['is_official'] == true,
        isQuickAlert: json['is_quick_alert'] == true,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        likesCount: json['likes_count'] as int? ?? 0,
        commentsCount: json['comments_count'] as int? ?? 0,
        sharesCount: json['shares_count'] as int? ?? 0,
        isTrending: json['is_trending'] == true,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        likedByMe: json['liked_by_me'] == true,
        media: ((json['media'] as List?) ?? []).map((e) => PostMediaItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<CommunityPost> _posts = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'all';

  bool _showCreatePost = false;
  String _newCategoryLabel = 'General Alert';
  final TextEditingController _postController = TextEditingController();
  final List<File> _composerMedia = [];
  bool _attachLocation = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    double? lat;
    double? lng;
    if (_selectedFilter == 'nearby') {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
            ).timeout(const Duration(seconds: 10));
            lat = double.parse(position.latitude.toStringAsFixed(6));
            lng = double.parse(position.longitude.toStringAsFixed(6));
          }
        }
      } catch (_) {}
    }

    try {
      final list = await CommunityService.listPosts(type: _selectedFilter, lat: lat, lng: lng);
      if (!mounted) return;
      setState(() {
        _posts = list.map((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } on CommunityException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 75);
      if (picked.isNotEmpty) {
        setState(() => _composerMedia.addAll(picked.map((x) => File(x.path))));
      }
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    try {
           final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final size = await File(picked.path).length();
        if (!mounted) return;
        if (size > 60 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That video is larger than 60MB. Please choose a shorter one.')),
          );
          return;
        }
        setState(() => _composerMedia.add(File(picked.path)));
      }
    } catch (_) {}
  }

  Future<void> _handleCreatePost() async {
    if (_postController.text.trim().isEmpty) return;
    setState(() => _posting = true);

    double? lat;
    double? lng;
    String locationDescription = '';
    if (_attachLocation) {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
            ).timeout(const Duration(seconds: 10));
            lat = double.parse(position.latitude.toStringAsFixed(6));
            lng = double.parse(position.longitude.toStringAsFixed(6));
            locationDescription = 'Current location';
          }
        }
      } catch (_) {}
    }

    try {
      await CommunityService.createPost(
        postType: 'alert',
        category: _categoryValues[_newCategoryLabel] ?? 'general_alert',
        content: _postController.text.trim(),
        locationDescription: locationDescription,
        latitude: lat,
        longitude: lng,
        media: _composerMedia.isEmpty ? null : _composerMedia,
      );
      if (!mounted) return;
      setState(() {
        _postController.clear();
        _composerMedia.clear();
        _attachLocation = false;
        _showCreatePost = false;
        _posting = false;
      });
      _loadPosts();
    } on CommunityException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _handleLike(CommunityPost post) async {
    final wasLiked = post.likedByMe;
    setState(() {
      post.likedByMe = !wasLiked;
      post.likesCount += wasLiked ? -1 : 1;
    });
    try {
      final result = await CommunityService.toggleLike(post.id);
      if (!mounted) return;
      setState(() {
        post.likedByMe = result['liked'] == true;
        post.likesCount = result['likes_count'] as int? ?? post.likesCount;
      });
    } on CommunityException catch (e) {
      if (!mounted) return;
      setState(() {
        post.likedByMe = wasLiked;
        post.likesCount += wasLiked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _handleShare(CommunityPost post) async {
    try {
      final result = await CommunityService.sharePost(post.id);
      if (!mounted) return;
      setState(() => post.sharesCount = result['shares_count'] as int? ?? post.sharesCount + 1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared to your network.')));
    } on CommunityException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openComments(CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CommentsSheet(
        post: post,
        onCommentAdded: () => setState(() => post.commentsCount += 1),
      ),
    );
  }

  void _openReportDialog(CommunityPost post) {
    String reasonLabel = _reportReasons.keys.first;
    final detailsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Report Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reasonLabel,
                items: _reportReasons.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (v) => setDialogState(() => reasonLabel = v!),
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsCtrl,
                maxLines: 3,
                decoration: InputDecoration(hintText: 'Additional details (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545)),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await CommunityService.reportPost(post.id, reason: _reportReasons[reasonLabel]!, details: detailsCtrl.text.trim());
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Our team will review this post.')));
                } on CommunityException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerQuickAlert() async {
    final messageCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quick Alert'),
        content: TextField(
          controller: messageCtrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: 'What\'s happening? (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Alert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    double? lat;
    double? lng;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          ).timeout(const Duration(seconds: 10));
          lat = double.parse(position.latitude.toStringAsFixed(6));
          lng = double.parse(position.longitude.toStringAsFixed(6));
        }
      }
    } catch (_) {}

    try {
      await CommunityService.quickAlert(message: messageCtrl.text.trim(), latitude: lat, longitude: lng);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quick Alert sent to nearby community!')));
      _loadPosts();
    } on CommunityException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'alert':
        return const Color(0xFF856404);
      case 'warning':
        return const Color(0xFF721C24);
      case 'wanted':
        return const Color(0xFF0C5460);
      default:
        return Colors.grey;
    }
  }

  Color _typeBg(String type) {
    switch (type) {
      case 'alert':
        return const Color(0xFFFFF3CD);
      case 'warning':
        return const Color(0xFFF8D7DA);
      case 'wanted':
        return const Color(0xFFD1ECF1);
      default:
        return const Color(0xFFF0F0F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadPosts,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildFilterTabs(),
                if (_showCreatePost) ...[
                  const SizedBox(height: 16),
                  _buildCreatePostCard(),
                ],
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  Column(
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))),
                      OutlinedButton(onPressed: _loadPosts, child: const Text('Retry')),
                    ],
                  )
                else if (_posts.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No posts yet.', style: TextStyle(color: Colors.grey))))
                else
                  ..._posts.map((post) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildPostCard(post))),
                const SizedBox(height: 60),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: GestureDetector(
              onTap: _triggerQuickAlert,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)]),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: Color(0xFF007BFF), size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community Feed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                SizedBox(height: 2),
                Text('Real-time safety reports near you', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => setState(() => _showCreatePost = !_showCreatePost),
            icon: const Icon(Icons.post_add_rounded, size: 18, color: Colors.white),
            label: const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = const [
      ['all', 'All Posts'],
      ['nearby', 'Nearby'],
      ['viral', 'Trending'],
      ['alert', 'Alerts'],
      ['wanted', 'Wanted'],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = _selectedFilter == f[0];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(f[1]),
                selected: isActive,
                onSelected: (_) {
                  setState(() => _selectedFilter = f[0]);
                  _loadPosts();
                },
                selectedColor: const Color(0xFF007BFF),
                backgroundColor: const Color(0xFFF0F2F5),
                labelStyle: TextStyle(color: isActive ? Colors.white : const Color(0xFF555555), fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide.none,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCreatePostCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 14)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Create a Community Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(onTap: () => setState(() => _showCreatePost = false), child: const Icon(Icons.close_rounded, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _newCategoryLabel,
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            items: _categoryLabels.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _newCategoryLabel = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "What's happening in your community? Share alerts, report incidents...",
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (_composerMedia.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _composerMedia.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final file = _composerMedia[i];
                  final isVideo = file.path.toLowerCase().endsWith('.mp4') || file.path.toLowerCase().endsWith('.mov');
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isVideo
                            ? Container(width: 70, height: 70, color: Colors.black87, child: const Icon(Icons.videocam_rounded, color: Colors.white))
                            : Image.file(file, width: 70, height: 70, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _composerMedia.removeAt(i)),
                          child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _mediaButton(Icons.camera_alt_outlined, 'Photo', onTap: _pickPhotos)),
              const SizedBox(width: 10),
              Expanded(child: _mediaButton(Icons.videocam_outlined, 'Video', onTap: _pickVideo)),
              const SizedBox(width: 10),
              Expanded(
                child: _mediaButton(
                  _attachLocation ? Icons.location_on_rounded : Icons.location_on_outlined,
                  _attachLocation ? 'Location ✓' : 'Location',
                  onTap: () => setState(() => _attachLocation = !_attachLocation),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28A745),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _posting ? null : _handleCreatePost,
              child: _posting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Post to Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaButton(IconData icon, String label, {required VoidCallback onTap}) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFF0F2F5),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: const Color(0xFF555555)),
      label: Text(label, style: const TextStyle(color: Color(0xFF555555), fontSize: 12)),
    );
  }

   void _openProfile(CommunityPost post) {
    final id = post.authorId;
    if (id == null) return;
    showUserProfileSheet(
      context,
      userId: id,
      name: post.authorName,
      photoUrl: post.authorPhoto,
      subtitle: post.isOfficial ? 'Verified official account' : null,
    );
  }

  Widget _initialsAvatar(CommunityPost post) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)])),
      child: Center(child: Text(post.authorAvatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
    );
  }

  Widget _authorAvatar(CommunityPost post) {
    final photo = post.authorPhoto;
    if (photo == null || photo.isEmpty) return _initialsAvatar(post);
    return ClipOval(
      child: Image.network(photo, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initialsAvatar(post)),
    );
  }

  Widget _buildPostCard(CommunityPost post) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tap the picture or name to open the person's profile.
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _openProfile(post),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _authorAvatar(post),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(child: Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis)),
                                  if (post.isOfficial) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF007BFF)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [if (post.locationDescription.isNotEmpty) post.locationDescription, _timeAgo(post.createdAt)].join(' • '),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (post.isTrending)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)]), borderRadius: BorderRadius.circular(12)),
                        child: const Text('🔥 Trending', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _typeBg(post.postType), borderRadius: BorderRadius.circular(12)),
                      child: Text(post.categoryDisplay.toUpperCase(), style: TextStyle(color: _typeColor(post.postType), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(post.content, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF333333))),
          ),
          if (post.media.isNotEmpty) _buildMediaGallery(post.media),
          if (post.distanceKm != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF8F9FA),
              width: double.infinity,
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF007BFF)),
                  const SizedBox(width: 6),
                  Text('${post.distanceKm} km away', style: const TextStyle(fontSize: 12, color: Color(0xFF007BFF))),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${post.likesCount} likes', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                Text('${post.commentsCount} comments • ${post.sharesCount} shares', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: _postActionButton(
                    post.likedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                    'Like',
                    onTap: () => _handleLike(post),
                    color: post.likedByMe ? const Color(0xFF007BFF) : null,
                  ),
                ),
                Expanded(child: _postActionButton(Icons.mode_comment_outlined, 'Comment', onTap: () => _openComments(post))),
                Expanded(child: _postActionButton(Icons.share_outlined, 'Share', onTap: () => _handleShare(post))),
                Expanded(child: _postActionButton(Icons.warning_amber_rounded, 'Report', color: const Color(0xFFDC3545), onTap: () => _openReportDialog(post))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGallery(List<PostMediaItem> media) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = media[i];
          return GestureDetector(
            onTap: () => _openMediaViewer(media, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.mediaType == 'video'
                  ? Container(
                      width: 260,
                      color: const Color(0xFFE9EEF6),
                      child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 48, color: Color(0xFF555555))),
                    )
                  : Image.network(
                      item.url,
                      width: 260,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 260, color: const Color(0xFFE9EEF6), child: const Icon(Icons.broken_image_outlined, color: Colors.grey)),
                      loadingBuilder: (context, child, progress) => progress == null ? child : Container(width: 260, color: const Color(0xFFE9EEF6), child: const Center(child: CircularProgressIndicator())),
                    ),
            ),
          );
        },
      ),
    );
  }

  void _openMediaViewer(List<PostMediaItem> media, int startIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 450,
          child: PageView.builder(
            controller: PageController(initialPage: startIndex),
            itemCount: media.length,
            itemBuilder: (context, i) {
              final item = media[i];
                           if (item.mediaType == 'video') {
                return VideoViewer(key: ValueKey(item.url), url: item.url);
              }
              return InteractiveViewer(child: Image.network(item.url, fit: BoxFit.contain));
            },
          ),
        ),
      ),
    );
  }

   Widget _postActionButton(IconData icon, String label, {VoidCallback? onTap, Color? color}) {
    final c = color ?? const Color(0xFF555555);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 5),
                            Text(label, maxLines: 1, softWrap: false, style: TextStyle(fontSize: 13, color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback onCommentAdded;

  const _CommentsSheet({required this.post, required this.onCommentAdded});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentData {
  final int? authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  _CommentData({required this.authorId, required this.authorName, required this.content, required this.createdAt});

  factory _CommentData.fromJson(Map<String, dynamic> json) => _CommentData(
        authorId: (json['author_id'] as num?)?.toInt(),
        authorName: json['author_name']?.toString() ?? 'Unknown',
        content: json['content']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<_CommentData> _comments = [];
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final list = await CommunityService.listComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = list.map((e) => _CommentData.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } on CommunityException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await CommunityService.createComment(widget.post.id, _commentCtrl.text.trim());
      _commentCtrl.clear();
      widget.onCommentAdded();
      await _loadComments();
    } on CommunityException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (!mounted) return;
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Comments', style: Theme.of(context).textTheme.titleLarge)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('No comments yet — be the first.', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length,
                        separatorBuilder: (_, _) => const Divider(height: 20),
                        itemBuilder: (context, i) {
                          final c = _comments[i];
                          // Tap a comment's author to open their profile.
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: c.authorId == null
                                ? null
                                : () => showUserProfileSheet(context, userId: c.authorId!, name: c.authorName),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF667EEA),
                                  radius: 16,
                                  child: Text(c.authorName.isNotEmpty ? c.authorName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          const SizedBox(width: 6),
                                          Text(_timeAgo(c.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(c.content, style: const TextStyle(fontSize: 13.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _submitComment,
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Color(0xFF007BFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}