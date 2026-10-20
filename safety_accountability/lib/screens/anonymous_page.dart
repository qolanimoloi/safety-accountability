import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/location_field.dart';
import '../services/anonymous_service.dart';

class ReportCategory {
  final String value; // shown to the user
  final String slug; // sent to Django
  final IconData icon;
  final String description;
  const ReportCategory({required this.value, required this.slug, required this.icon, required this.description});
}

const List<ReportCategory> _categories = [
  ReportCategory(value: 'Drug Activity', slug: 'drug_activity', icon: Icons.medication_rounded, description: 'Drug dealing or substance abuse'),
  ReportCategory(value: 'Sexual Harassment', slug: 'sexual_harassment', icon: Icons.report_problem_rounded, description: 'Workplace or academic harassment'),
  ReportCategory(value: 'Sexual Abuse', slug: 'sexual_abuse', icon: Icons.gpp_bad_rounded, description: 'Sexual assault or abuse cases'),
  ReportCategory(value: 'GBV', slug: 'gbv', icon: Icons.shield_rounded, description: 'Gender-based violence'),
  ReportCategory(value: 'Child Abuse', slug: 'child_abuse', icon: Icons.child_care_rounded, description: 'Any form of child abuse'),
  ReportCategory(value: 'Human Trafficking', slug: 'human_trafficking', icon: Icons.link_off_rounded, description: 'Trafficking or exploitation'),
  ReportCategory(value: 'Corruption', slug: 'corruption', icon: Icons.attach_money_rounded, description: 'Bribery, fraud, or corruption'),
  ReportCategory(value: 'Illegal Campaign', slug: 'illegal_campaign', icon: Icons.campaign_rounded, description: 'Fraudulent or illegal campaigns'),
  ReportCategory(value: 'Domestic Violence', slug: 'domestic_violence', icon: Icons.home_rounded, description: 'Abuse happening at home'),
  ReportCategory(value: 'Other', slug: 'other', icon: Icons.more_horiz_rounded, description: 'Other illegal activities'),
];

class AnonReport {
  final String category;
  final String location;
  final String description;
  final int evidenceCount;
  final String date;
  final String statusKey;
  final String statusLabel;
  final String trackingCode;

  AnonReport({
    required this.category,
    required this.location,
    required this.description,
    required this.evidenceCount,
    required this.date,
    required this.statusKey,
    required this.statusLabel,
    required this.trackingCode,
  });

  factory AnonReport.fromJson(Map<String, dynamic> j) {
    final created = (j['created_at'] ?? '').toString();
    final evidence = j['evidence'];
    return AnonReport(
      category: (j['category_display'] ?? j['category'] ?? '').toString(),
      location: (j['location'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      evidenceCount: evidence is List ? evidence.length : 0,
      date: created.contains('T') ? created.split('T')[0] : created,
      statusKey: (j['status'] ?? '').toString(),
      statusLabel: (j['status_display'] ?? j['status'] ?? '').toString(),
      trackingCode: (j['tracking_code'] ?? '').toString(),
    );
  }
}

class AnonymousPage extends StatefulWidget {
  const AnonymousPage({super.key});

  @override
  State<AnonymousPage> createState() => _AnonymousPageState();
}

enum _AnonView { info, form, myReports }

class _AnonymousPageState extends State<AnonymousPage> {
  static const int _maxFileBytes = 50 * 1024 * 1024;

  _AnonView _view = _AnonView.info;

  // Real data, loaded from the server using codes saved on this device.
  List<AnonReport> _reports = [];
  bool _loadingReports = false;
  String? _reportsError;

  String? _selectedCategory; // display name
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _trackController = TextEditingController();
  String _urgency = 'medium';
  bool _involveMinors = false;
  bool _requiresImmediate = false;
  final List<PlatformFile> _uploadedFiles = [];

  bool _submitting = false;
  bool _tracking = false;
  bool _submissionSuccess = false;
  String _trackingCode = '';
  Timer? _successTimer;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _locationController.dispose();
    _descController.dispose();
    _trackController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------- data

  Future<void> _loadReports() async {
    setState(() {
      _loadingReports = true;
      _reportsError = null;
    });
    try {
      final codes = await AnonymousService.getSavedCodes();
      final loaded = <AnonReport>[];
      var failed = 0;
      for (final code in codes) {
        try {
          final json = await AnonymousService.trackReport(code);
          loaded.add(AnonReport.fromJson(json));
        } catch (_) {
          failed++;
        }
      }
      if (!mounted) return;
      setState(() {
        _reports = loaded;
        if (failed > 0 && loaded.isEmpty) {
          _reportsError = 'Could not load your reports. Check your connection and pull to refresh.';
        }
      });
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _trackByCode() async {
    final code = _trackController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _tracking = true);
    try {
      final json = await AnonymousService.trackReport(code);
      await AnonymousService.saveCode(code);
      _trackController.clear();
      await _loadReports();
      if (json.isNotEmpty) _toast('Report found and added to your list.');
    } on AnonymousException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _tracking = false);
    }
  }

  Future<void> _removeSavedReport(AnonReport r) async {
    await AnonymousService.removeCode(r.trackingCode);
    if (!mounted) return;
    setState(() => _reports.removeWhere((x) => x.trackingCode == r.trackingCode));
  }

    Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'mp3', 'wav', 'pdf', 'doc', 'docx'],
    );
    if (files.isEmpty) return;

    final accepted = <PlatformFile>[];
    var tooBig = 0;
    for (final f in files) {
      final bytes = f.lengthSync() ?? 0;
      if (bytes > _maxFileBytes) {
        tooBig++;
      } else {
        accepted.add(f);
      }
    }
    setState(() => _uploadedFiles.addAll(accepted));
    if (tooBig > 0) _toast('$tooBig file(s) skipped: over the 50MB limit.');
  }

  void _removeFile(int index) {
    setState(() => _uploadedFiles.removeAt(index));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  IconData _fileIcon(String? ext) {
    if (ext == null) return Icons.insert_drive_file_rounded;
    final e = ext.toLowerCase();
    if (['jpg', 'jpeg', 'png'].contains(e)) return Icons.image_rounded;
    if (['mp4', 'mov'].contains(e)) return Icons.videocam_rounded;
    if (['mp3', 'wav'].contains(e)) return Icons.mic_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Future<void> _submitReport() async {
    if (_submitting) return;
    if (_selectedCategory == null || _descController.text.trim().isEmpty) {
      _toast('Choose a category and add a description.');
      return;
    }

    final category = _categories.firstWhere((c) => c.value == _selectedCategory);
    setState(() => _submitting = true);
    try {
      final code = await AnonymousService.submitReport(
        category: category.slug,
        location: _locationController.text.trim(),
        description: _descController.text.trim(),
        urgency: _urgency,
        involvesMinors: _involveMinors,
        requiresImmediateAction: _requiresImmediate,
        files: List<PlatformFile>.from(_uploadedFiles),
      );
      if (!mounted) return;
      setState(() {
        _trackingCode = code;
        _submissionSuccess = true;
        _selectedCategory = null;
        _locationController.clear();
        _descController.clear();
        _urgency = 'medium';
        _involveMinors = false;
        _requiresImmediate = false;
        _uploadedFiles.clear();
      });
      _successTimer?.cancel();
      _successTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _submissionSuccess = false);
      });
      _loadReports();
    } on AnonymousException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroHeader(),
          const SizedBox(height: 16),
          _buildSafetyBanner(),
          if (_submissionSuccess) ...[
            const SizedBox(height: 16),
            _buildSuccessMessage(),
          ],
          const SizedBox(height: 16),
          if (_view == _AnonView.form)
            _buildReportForm()
          else if (_view == _AnonView.myReports)
            _buildMyReports()
          else
            _buildInfoSection(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF667EEA).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Anonymous Reporting', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                    SizedBox(height: 3),
                    Text('Report illegal activities safely and anonymously', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final opening = _view != _AnonView.myReports;
                    setState(() => _view = opening ? _AnonView.myReports : _AnonView.info);
                    if (opening) _loadReports();
                  },
                  icon: Icon(_view == _AnonView.myReports ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                  label: const Text('My Reports'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC3545),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => setState(() => _view = _view == _AnonView.form ? _AnonView.info : _AnonView.form),
                  icon: const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.white),
                  label: const Text('Make Report', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF28A745), Color(0xFF20C997)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Your identity is completely protected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text('Reports are not linked to your account. No personal information is stored with your report. You remain anonymous.',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF28A745), Color(0xFF20C997)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Report Submitted Successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text.rich(TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  children: [
                    const TextSpan(text: 'Your tracking code: '),
                    TextSpan(text: _trackingCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                const SizedBox(height: 4),
                const Text('Save this code. It is also stored on this phone under My Reports.', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Submit Anonymous Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              GestureDetector(onTap: () => setState(() => _view = _AnonView.info), child: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05),
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final selected = _selectedCategory == cat.value;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: selected ? const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]) : null,
                    color: selected ? null : const Color(0xFFF8F9FA),
                    border: Border.all(color: selected ? const Color(0xFF667EEA) : const Color(0xFFE0E0E0), width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat.icon, size: 26, color: selected ? Colors.white : const Color(0xFF667EEA)),
                      const SizedBox(height: 8),
                      Text(cat.value, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(cat.description, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 22),
                        LocationField(
              controller: _locationController,
              label: 'Location (optional but recommended)',
              hint: 'Search street, building, area...',
            ),
            const SizedBox(height: 18),
            const Text('Detailed Description *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: 'Provide as much detail as possible...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            Align(alignment: Alignment.centerRight, child: Text('${_descController.text.length} characters', style: const TextStyle(fontSize: 11, color: Colors.grey))),
            const SizedBox(height: 18),
            const Text('Urgency Level', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                _urgencyButton('low', 'Low', const Color(0xFF28A745)),
                const SizedBox(width: 8),
                _urgencyButton('medium', 'Medium', const Color(0xFFFFC107)),
                const SizedBox(width: 8),
                _urgencyButton('high', 'High', const Color(0xFFFD7E14)),
                const SizedBox(width: 8),
                _urgencyButton('critical', 'Critical', const Color(0xFFDC3545)),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Color(0xFFFFC107), width: 4))),
              child: Column(
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _involveMinors,
                    onChanged: (v) => setState(() => _involveMinors = v ?? false),
                    title: const Text('This involves minors (under 18)', style: TextStyle(fontSize: 13)),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _requiresImmediate,
                    onChanged: (v) => setState(() => _requiresImmediate = v ?? false),
                    title: const Text('Requires immediate action (life-threatening)', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Upload Evidence (Photos, Videos, Audio, Documents)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickFiles,
              child: Container(
                padding: const EdgeInsets.all(28),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDEE2E6), width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFF8F9FA),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.upload_rounded, size: 30, color: Color(0xFF667EEA)),
                    SizedBox(height: 8),
                    Text('Tap to upload', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Max 50MB per file', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            if (_uploadedFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._uploadedFiles.asMap().entries.map((entry) {
                final file = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0E0E0))),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFF667EEA).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(_fileIcon(file.extension), color: const Color(0xFF667EEA), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                           Text(_formatSize(file.lengthSync() ?? 0), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC3545)), onPressed: _submitting ? null : () => _removeFile(entry.key)),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(child: Text('Your report is not linked to your account.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _submitting ? null : _submitReport,
                      icon: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(_submitting ? 'Submitting...' : 'Submit Anonymous Report', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _urgencyButton(String level, String label, Color color) {
    final active = _urgency == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgency = level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color : Colors.white,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : color, fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),
    );
  }

  Color _statusColor(String statusKey) {
    switch (statusKey) {
      case 'submitted':
        return const Color(0xFFB38F00);
      case 'under_investigation':
        return const Color(0xFF667EEA);
      case 'resolved':
        return const Color(0xFF28A745);
      default:
        return Colors.grey;
    }
  }

  Widget _buildMyReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('Your Anonymous Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            IconButton(onPressed: _loadingReports ? null : _loadReports, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Track your submitted reports using tracking codes', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _trackController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter a tracking code (ANO-2026-1234)',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _tracking ? null : _trackByCode,
              child: _tracking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Track', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_loadingReports)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_reportsError != null)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text(_reportsError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          )
        else if (_reports.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF667EEA).withValues(alpha: 0.3), width: 2)),
            child: const Column(
              children: [
                Icon(Icons.warning_amber_rounded, size: 44, color: Color(0xFF667EEA)),
                SizedBox(height: 16),
                Text('No reports yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Your submitted reports will appear here', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )
        else
          ..._reports.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(r.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: _statusColor(r.statusKey).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                          child: Text(r.statusLabel.toUpperCase(), style: TextStyle(color: _statusColor(r.statusKey), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r.location.isEmpty ? 'Location not specified' : r.location, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                    ]),
                    const SizedBox(height: 10),
                    Text(r.description.length > 120 ? '${r.description.substring(0, 120)}...' : r.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.attach_file_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${r.evidenceCount} files', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 16),
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(r.date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF667EEA).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tracking:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          Text(r.trackingCode, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF667EEA), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _removeSavedReport(r),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC3545)),
                        label: const Text('Remove from this phone', style: TextStyle(color: Color(0xFFDC3545), fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: Text('Why Report Anonymously?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 18),
        _infoCard(Icons.shield_rounded, 'Complete Anonymity', 'Your identity is never collected or stored with your report. It is not linked to your account.'),
        const SizedBox(height: 14),
        _infoCard(Icons.warning_amber_rounded, 'Make a Difference', 'Your report can help stop illegal activities and protect vulnerable individuals in your community.'),
        const SizedBox(height: 14),
        _infoCard(Icons.check_circle_rounded, 'Track Progress', 'Use your tracking code to follow the status of your report without revealing your identity.'),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What You Can Report:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._categories.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [Icon(c.icon, size: 18, color: const Color(0xFF667EEA)), const SizedBox(width: 10), Text(c.value, style: const TextStyle(fontSize: 14))]),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(14), border: const Border(left: BorderSide(color: Color(0xFFDC3545), width: 5))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC3545)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('In Case of Emergency', style: TextStyle(color: Color(0xFFDC3545), fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 6),
                    Text('If someone is in immediate danger, call emergency services (10111) first, then submit a report here.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14)]),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF667EEA)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
        ],
      ),
    );
  }
}