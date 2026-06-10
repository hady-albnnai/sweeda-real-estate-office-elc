import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class SystemQaScreen extends StatefulWidget {
  const SystemQaScreen({super.key});

  @override
  State<SystemQaScreen> createState() => _SystemQaScreenState();
}

class _SystemQaScreenState extends State<SystemQaScreen> {
  bool _running = false;
  List<_QaCheck> _checks = [];
  Map<String, dynamic> _summary = {};
  String? _error;

  Future<void> _runChecks() async {
    setState(() {
      _running = true;
      _error = null;
      _checks = [];
      _summary = {};
    });

    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    final localChecks = <_QaCheck>[
      _QaCheck('local: userModel loaded', user != null, user?.uid ?? 'no user'),
      _QaCheck('local: is logged in', auth.isLoggedIn, auth.isLoggedIn.toString()),
      _QaCheck('local: role >= 2', (user?.role ?? -1) >= 2, 'role=${user?.role}'),
      _QaCheck('local: permissions loaded', user != null, 'perm=${user?.perm.length ?? 0}'),
    ];

    try {
      final result = await SupabaseService().client.rpc(
        'qa_system_check',
        params: {'p_admin_uid': user?.uid},
      );

      final map = Map<String, dynamic>.from(result as Map);
      final serverChecks = ((map['checks'] ?? []) as List)
          .map((item) => _QaCheck.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      if (!mounted) return;
      setState(() {
        _checks = [...localChecks, ...serverChecks];
        _summary = Map<String, dynamic>.from((map['summary'] ?? {}) as Map);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checks = localChecks;
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  int get _criticalFailed => _checks.where((check) => !check.ok && check.severity == 'critical').length;
  int get _warningFailed => _checks.where((check) => !check.ok && check.severity == 'warning').length;
  int get _passed => _checks.where((check) => check.ok).length;

  @override
  Widget build(BuildContext context) {
    final ready = _checks.isNotEmpty && _criticalFailed == 0;
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('فحص النظام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline, color: AppTheme.primaryGold),
            onPressed: _running ? null : _runChecks,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(ready),
          const SizedBox(height: 16),
          if (_error != null) _errorCard(_error!),
          if (_summary.isNotEmpty) _summaryCard(),
          const SizedBox(height: 12),
          if (_checks.isEmpty)
            _emptyState()
          else ...[
            ..._section('Critical', _checks.where((c) => c.severity == 'critical').toList()),
            ..._section('Warnings', _checks.where((c) => c.severity == 'warning').toList()),
            ..._section('Info', _checks.where((c) => c.severity == 'info').toList()),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: AppTheme.deepBlack,
        onPressed: _running ? null : _runChecks,
        icon: _running
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.fact_check_outlined),
        label: Text(_running ? 'جار الفحص...' : 'تشغيل الفحص'),
      ),
    );
  }

  Widget _header(bool ready) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (ready ? Colors.green : AppTheme.primaryGold).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (ready ? Colors.green : AppTheme.primaryGold).withValues(alpha: 0.14),
            child: Icon(ready ? Icons.verified_outlined : Icons.fact_check_outlined,
                color: ready ? Colors.green : AppTheme.primaryGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'النظام جاهز مبدئياً' : 'فحص النظام الداخلي',
                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _checks.isEmpty
                      ? 'اضغط تشغيل الفحص للتحقق من الجداول والدوال والصلاحيات.'
                      : 'ناجح: $_passed — أخطاء: $_criticalFailed — تحذيرات: $_warningFailed',
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final entries = _summary.entries.toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries.map((entry) => _pill(entry.key, entry.value.toString())).toList(),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $value', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
    );
  }

  Widget _errorCard(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.35)),
      ),
      child: Text(error, style: const TextStyle(color: AppTheme.errorRed, fontSize: 12)),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(
        child: Text('لم يتم تشغيل الفحص بعد', style: TextStyle(color: AppTheme.textGrey)),
      ),
    );
  }


  List<Widget> _section(String title, List<_QaCheck> items) {
    if (items.isEmpty) return const [];
    final failed = items.where((item) => !item.ok).length;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Row(
          children: [
            Text(
              '$title (${items.length})',
              style: const TextStyle(color: AppTheme.primaryGold, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (failed > 0) ...[
              const SizedBox(width: 8),
              Text('غير ناجح: $failed', style: const TextStyle(color: AppTheme.errorRed, fontSize: 12)),
            ],
          ],
        ),
      ),
      ...items.map(_checkTile),
    ];
  }

  Widget _checkTile(_QaCheck check) {
    final color = check.ok ? Colors.green : (check.severity == 'warning' ? Colors.orange : AppTheme.errorRed);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: ListTile(
        leading: Icon(check.ok ? Icons.check_circle_outline : Icons.error_outline, color: color),
        title: Text(check.name, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(check.details, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
        trailing: Text(check.ok ? 'OK' : check.severity.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }
}

class _QaCheck {
  final String name;
  final bool ok;
  final String details;
  final String severity;
  final String category;

  _QaCheck(this.name, this.ok, this.details, {this.severity = 'critical', this.category = 'local'});

  factory _QaCheck.fromMap(Map<String, dynamic> map) {
    return _QaCheck(
      map['name']?.toString() ?? 'unknown',
      map['ok'] == true,
      map['details']?.toString() ?? '',
      severity: map['severity']?.toString() ?? 'critical',
      category: map['category']?.toString() ?? '',
    );
  }
}
