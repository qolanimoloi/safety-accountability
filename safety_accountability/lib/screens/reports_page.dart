import 'package:flutter/material.dart';
import '../services/news_service.dart';

Color _categoryColor(String category) {
  switch (category) {
    case 'alert':
      return const Color(0xFFDC3545);
    case 'tip':
      return const Color(0xFF28A745);
    default:
      return const Color(0xFF667EEA);
  }
}

String _categoryLabel(String category) {
  switch (category) {
    case 'alert':
      return 'ALERT';
    case 'tip':
      return 'SAFETY TIP';
    default:
      return 'STATS';
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'alert':
      return Icons.warning_amber_rounded;
    case 'tip':
      return Icons.lightbulb_rounded;
    default:
      return Icons.bar_chart_rounded;
  }
}

String _relativeTime(String? isoDate) {
  final date = DateTime.tryParse(isoDate ?? '');
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  final weeks = (diff.inDays / 7).floor();
  return '$weeks week${weeks == 1 ? '' : 's'} ago';
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _showWeek = true;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = [];
  Map<String, dynamic> _stats = const {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([NewsService.listPosts(), NewsService.stats()]);
      if (!mounted) return;
      setState(() {
        _posts = results[0] as List<Map<String, dynamic>>;
        _stats = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } on NewsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = (_stats[_showWeek ? 'week' : 'month'] as Map?)?.cast<String, dynamic>() ??
        const {'total': '0', 'resolved': '0', 'investigating': '0', 'response': 'N/A'};

    return Container(
      color: const Color(0xFFF5F7FA),
      child: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildToggle(),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _buildErrorState()
            else ...[
              _buildStatsGrid(stats),
              const SizedBox(height: 22),
              const Text('Community Updates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('News, alerts and safety tips from the admin team', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 14),
              if (_posts.isEmpty)
                _buildEmptyState()
              else
                ..._posts.map((p) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _NewsCard(post: p))),
            ],
          ],
        ),
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
          const Icon(Icons.feed_rounded, color: Color(0xFF667EEA), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Safety Reports & News', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Stay informed about what\'s happening around you', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _toggleButton('This Week', _showWeek, () => setState(() => _showWeek = true))),
          Expanded(child: _toggleButton('This Month', !_showWeek, () => setState(() => _showWeek = false))),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: active ? const Color(0xFF667EEA) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _statCard('Total Reports', stats['total']?.toString() ?? '0', Icons.description_rounded, const Color(0xFF667EEA)),
        _statCard('Resolved', stats['resolved']?.toString() ?? '0', Icons.check_circle_rounded, const Color(0xFF28A745)),
        _statCard('Investigating', stats['investigating']?.toString() ?? '0', Icons.search_rounded, const Color(0xFFFFC107)),
        _statCard('Avg Response', stats['response']?.toString() ?? 'N/A', Icons.timer_rounded, const Color(0xFFDC3545)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.feed_outlined, size: 46, color: Colors.grey),
          SizedBox(height: 14),
          Text('No community updates yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Check back soon for news and safety tips', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(28),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_error ?? 'Could not load this right now.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadAll, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _NewsCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final category = post['category'] as String? ?? 'tip';
    final color = _categoryColor(category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(_categoryIcon(category), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_categoryLabel(category), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(post['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(post['body']?.toString() ?? '', style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF444444))),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 13, color: Colors.grey),
              const SizedBox(width: 5),
              Text(_relativeTime(post['created_at']?.toString()), style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
              const Spacer(),
              const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF667EEA)),
              const SizedBox(width: 4),
              Text(post['posted_by_name']?.toString() ?? 'Admin', style: const TextStyle(fontSize: 11.5, color: Color(0xFF667EEA), fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}