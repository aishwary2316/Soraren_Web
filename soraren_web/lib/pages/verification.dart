// lib/pages/verification.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../utils/safe_error.dart';
import '../services/api_service.dart';

/// Enum for per-field states (top-level as required)
enum FieldState { normal, suspicious, missing, serviceUnavailable }

/// High-level wrapper: creates ApiService and calls showVerificationDialog.
Future<void> verifySuspectAndShowDialog(
    BuildContext context, {
      String? imagePath,
      String location = 'Imphal-HQ',
    }) async {
  final api = ApiService();
  await showVerificationDialog(
    context,
    api: api,
    imagePath: imagePath,
    location: location,
  );
}

/// Performs the verification call via ApiService and shows the rich dialog.
Future<void> showVerificationDialog(
    BuildContext context, {
      required ApiService api,
      String? imagePath,
      String location = 'Imphal-HQ',
    }) async {
  if (imagePath == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please provide a Suspect image to verify.')),
    );
    return;
  }

  // Show loading while contacting server
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Container(
      color: Colors.black54,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1E40AF)),
                SizedBox(height: 12),
                Text(
                  'Identifying Suspect...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Map<String, dynamic> bodyMap = {};

  try {
    // Calling the API service's recognizeSuspect method
    final result = await api.recognizeSuspect(File(imagePath));

    if (result['ok'] == true) {
      final d = result['data'];
      bodyMap['suspectData'] = {
        'status': (d['match'] == true || d['status'] == 'ALERT' || d['status'] == 'MATCH') ? 'ALERT' : 'CLEAR',
        'name': d['person_name'] ?? 'N/A',
        'score': d['confidence'] ?? d['score'] ?? 0.0,
        'crime_involved': d['crime_involved'] ?? 'N/A',
        'description': d['description'] ?? 'No criminal history found in the current session.',
        'message': d['message'] ?? (d['match'] == true ? 'MATCH FOUND IN DATABASE' : 'NO RECORD FOUND'),
        'closest_match': d['closest_match'],
      };
      if (bodyMap['suspectData']['status'] == 'ALERT') {
        bodyMap['suspicious'] = true;
      }
    } else {
      bodyMap['suspectData'] = {
        'status': 'SERVICE_UNAVAILABLE',
        'message': result['message'] ?? 'Face recognition service failed.',
      };
    }
  } catch (e) {
    bodyMap['suspectData'] = {
      'status': 'SERVICE_UNAVAILABLE',
      'message': SafeError.format(e, fallback: "Network error contacting database."),
    };
  }

  // Dismiss loading dialog
  try {
    Navigator.of(context, rootNavigator: true).pop();
  } catch (_) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  if (bodyMap.isEmpty) {
    bodyMap = {
      'suspectData': {'status': 'N/A', 'provided': true},
      'suspicious': false,
    };
  }

  // Navigate to the full-page dashboard
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => VerificationDashboard(api: api, body: bodyMap, imagePath: imagePath),
    ),
  );
}

class VerificationDashboard extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> body;
  final String imagePath;

  const VerificationDashboard({
    super.key,
    required this.api,
    required this.body,
    required this.imagePath
  });

  @override
  State<VerificationDashboard> createState() => _VerificationDashboardState();
}

class _VerificationDashboardState extends State<VerificationDashboard> with TickerProviderStateMixin {
  bool _showRawJson = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut)
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Responsive scale helper for consistent UI across devices
  double _scale() {
    final w = MediaQuery.of(context).size.width;
    final raw = w / 390.0;
    return math.max(0.85, math.min(1.15, raw));
  }

  Map<String, dynamic>? get suspectData => widget.body['suspectData'] is Map
      ? Map<String, dynamic>.from(widget.body['suspectData'])
      : null;
  bool get suspiciousFlag => widget.body['suspicious'] == true;

  /// Extract concise user-facing reason
  String? _extractReason(Map<String, dynamic>? data) {
    if (data == null) return null;
    if (data['reason'] != null) return data['reason'].toString();
    if (data['message'] != null) return data['message'].toString();
    if (data['description'] != null) return data['description'].toString();

    final status = (data['status'] ?? '').toString();
    if (status.isNotEmpty) return status;

    return null;
  }

  /// Determine per-field state from API data
  FieldState _stateFromData(Map<String, dynamic>? data) {
    if (data == null) return FieldState.missing;
    final status = (data['status'] ?? '').toString().toLowerCase();

    if (status == 'alert' || status == 'match' || status == 'wanted' || status == 'criminal') {
      return FieldState.suspicious;
    }
    if (status == 'clear' || status == 'normal' || status == 'not_found' || status == 'n/a') {
      return FieldState.normal;
    }
    if (status == 'service_unavailable' || status.contains('unavailable') || status == 'error') {
      return FieldState.serviceUnavailable;
    }
    return FieldState.normal;
  }

  /// Build a list of suspicious reasons for the alert details section
  List<String> _suspiciousReasons() {
    final List<String> reasons = [];
    final faceSt = _stateFromData(suspectData);

    if (faceSt == FieldState.suspicious) {
      final r = _extractReason(suspectData) ?? 'Matched in database';
      reasons.add('Identity: $r');
    }

    if (suspiciousFlag && reasons.isEmpty) {
      reasons.add('Backend system flagged this interaction.');
    }

    return reasons;
  }

  FieldState get _faceState => _stateFromData(suspectData);
  bool get _anySuspicious => _faceState == FieldState.suspicious;
  bool get _anyMissingOrError => _faceState == FieldState.missing || _faceState == FieldState.serviceUnavailable;

  Color get _overallColor {
    if (_anySuspicious) return const Color(0xFFE53E3E);
    return const Color(0xFF38A169);
  }

  String get _overallText {
    if (_anySuspicious) return 'MATCH FOUND';
    return 'NO MATCH FOUND';
  }

  IconData get _overallIcon {
    if (_anySuspicious) return Icons.warning_amber_rounded;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale();
    final screenW = MediaQuery.of(context).size.width;
    final horizontalPadding = screenW > 600 ? 24.0 : 16.0;

    return Theme(
      data: Theme.of(context).copyWith(
        cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text('Verification Analysis', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18 * s)),
          centerTitle: true,
          backgroundColor: const Color(0xFF1E40AF),
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 20 * s),
              onPressed: () => Navigator.of(context).pop()
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 14 * s),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Top Status Banner
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16 * s),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_overallColor.withOpacity(0.12), _overallColor.withOpacity(0.04)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _overallColor.withOpacity(0.24), width: 1.0),
                    boxShadow: [BoxShadow(color: _overallColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Column(children: [
                    Icon(_overallIcon, color: _overallColor, size: 40 * s),
                    SizedBox(height: 8 * s),
                    Text(_overallText, style: TextStyle(color: _overallColor, fontWeight: FontWeight.bold, fontSize: 22 * s, letterSpacing: 0.8)),
                    SizedBox(height: 6 * s),
                    Text(
                      _anySuspicious
                          ? 'Identification confirmed in the official Manipur Police records.'
                          : (_anyMissingOrError ? 'Service temporarily unavailable.' : 'No matching suspect records found.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _overallColor.withOpacity(0.85), fontSize: 12 * s, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),

                SizedBox(height: 16 * s),

                // Identification Summary
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12 * s),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.assignment_turned_in, color: Colors.blue.shade700, size: 18 * s),
                      SizedBox(width: 10 * s),
                      Expanded(child: Text('Summary', style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.bold))),
                    ]),
                    SizedBox(height: 10 * s),
                    _buildSummaryRow(
                      title: 'Face Recognition',
                      state: _faceState,
                      reason: _extractReason(suspectData),
                      s: s,
                    ),
                  ]),
                ),

                SizedBox(height: 16 * s),

                // Suspect Information Card
                _buildInfoCard(
                  title: 'Suspect Information',
                  icon: Icons.person_search,
                  data: suspectData,
                  primaryKeys: ['name', 'status', 'crime_involved'],
                  detailsKeys: ['description', 'message', 'score', 'closest_match'],
                  color: Colors.indigo,
                  s: s,
                ),

                SizedBox(height: 18 * s),

                // Alert Details
                if (_suspiciousReasons().isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(left: 4 * s, bottom: 8 * s),
                    child: Text('ALERT DETAILS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 12 * s, letterSpacing: 0.5)),
                  ),
                  ..._suspiciousReasons().map((reason) => Container(
                    margin: EdgeInsets.only(bottom: 8 * s),
                    padding: EdgeInsets.all(12 * s),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade100)),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 18 * s),
                      SizedBox(width: 10 * s),
                      Expanded(child: Text(reason, style: TextStyle(color: Colors.red.shade900, fontSize: 13 * s, fontWeight: FontWeight.w500))),
                    ]),
                  )),
                  SizedBox(height: 10 * s),
                ],

                // JSON Toggle
                Center(
                  child: InkWell(
                    onTap: () => setState(() => _showRawJson = !_showRawJson),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_showRawJson ? Icons.visibility_off : Icons.code, size: 18 * s, color: Colors.grey.shade700),
                        SizedBox(width: 8 * s),
                        Text(_showRawJson ? 'Hide System Logs' : 'View System Logs', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 13 * s)),
                      ]),
                    ),
                  ),
                ),

                if (_showRawJson) ...[
                  SizedBox(height: 12 * s),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12 * s),
                    decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade700)),
                    child: SelectableText(
                      JsonEncoder.withIndent('  ').convert(widget.body),
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11 * s, color: Colors.green, height: 1.4),
                    ),
                  ),
                ],

                SizedBox(height: 20 * s),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: math.max(44 * s, 48),
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.close, size: 18 * s),
                    label: Text('Dismiss', style: TextStyle(fontSize: 14 * s)),
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                SizedBox(height: 12 * s),
              ]),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({required String title, required FieldState state, String? reason, required double s}) {
    Color getColor() {
      switch (state) {
        case FieldState.suspicious: return const Color(0xFFE53E3E);
        case FieldState.missing:
        case FieldState.serviceUnavailable: return Colors.orange.shade700;
        case FieldState.normal:
        default: return const Color(0xFF38A169);
      }
    }
    IconData getIcon() {
      switch (state) {
        case FieldState.suspicious: return Icons.priority_high;
        case FieldState.missing:
        case FieldState.serviceUnavailable: return Icons.info_outline;
        case FieldState.normal:
        default: return Icons.check;
      }
    }
    final c = getColor();
    final icon = getIcon();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8 * s),
            decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18 * s, color: c),
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * s)),
              SizedBox(height: 4 * s),
              Text(reason ?? (state == FieldState.normal ? 'Record clear' : 'Service unavailable'), style: TextStyle(color: c, fontSize: 12 * s)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic>? data,
    required List<String> primaryKeys,
    required List<String> detailsKeys,
    required Color color,
    required double s,
  }) {
    if (data == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(12 * s),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: const Text('No profile data available.'),
      );
    }

    bool isError = (data['status'] == 'ERROR' || data['status'] == 'SERVICE_UNAVAILABLE');
    Color cardColor = isError ? Colors.orange.shade50 : Colors.white;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.all(12 * s),
          decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Container(padding: EdgeInsets.all(8 * s), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20 * s)),
            SizedBox(width: 12 * s),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.bold, color: Colors.black87))),
          ]),
        ),

        Padding(
          padding: EdgeInsets.all(12 * s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // WEB FIX: Conditional image rendering
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: kIsWeb
                    ? Image.network(
                  widget.imagePath,
                  width: math.min(180 * s, MediaQuery.of(context).size.width * 0.5),
                  height: math.min(180 * s, MediaQuery.of(context).size.width * 0.5),
                  fit: BoxFit.cover,
                )
                    : Image.file(
                  File(widget.imagePath),
                  width: math.min(180 * s, MediaQuery.of(context).size.width * 0.5),
                  height: math.min(180 * s, MediaQuery.of(context).size.width * 0.5),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 14 * s),

            ...primaryKeys.where((key) => data.containsKey(key)).map((key) {
              final value = data[key].toString();
              return Padding(
                padding: EdgeInsets.only(bottom: 10 * s),
                child: Container(
                  padding: EdgeInsets.all(12 * s),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(children: [
                    Container(width: 4 * s, height: 18 * s, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                    SizedBox(width: 10 * s),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_formatLabel(key), style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                        SizedBox(height: 6 * s),
                        Text(value, style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w600, color: (key == 'status' && value == 'ALERT') ? Colors.red : Colors.black87)),
                      ]),
                    ),
                  ]),
                ),
              );
            }).toList(),

            if (detailsKeys.any((key) => data.containsKey(key)))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.only(top: 6 * s),
                leading: Container(padding: EdgeInsets.all(6 * s), decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.analytics_outlined, color: color, size: 16 * s)),
                title: Text('Database Details', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black, fontSize: 14 * s)),
                children: [
                  Container(
                    padding: EdgeInsets.all(10 * s),
                    decoration: BoxDecoration(color: color.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.08))),
                    child: Column(
                      children: detailsKeys.where((key) => data.containsKey(key)).map((key) {
                        final value = data[key].toString();
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 6 * s),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 110 * s, child: Text(_formatLabel(key), style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                            Expanded(child: Text(value, style: TextStyle(fontSize: 13 * s, color: Colors.grey.shade800, height: 1.3))),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ]),
        ),
      ]),
    );
  }

  String _formatLabel(String key) {
    return key.replaceAll('_', ' ').split(' ').map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
  }
}