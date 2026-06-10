import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

/// 📊 التحليلات الشاملة — أرقام + أشرطة نسب (بدون مكتبات خارجية)
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _s = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final stats = await context.read<AdminProvider>().getStats(adminUid);
    if (mounted) {
      setState(() {
        _s = stats;
        _loading = false;
      });
    }
  }

  int _i(String k) => ((_s[k] ?? 0) as num).toInt();
  double _d(String k) => ((_s[k] ?? 0) as num).toDouble();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('التحليلات'),
        backgroundColor: AppTheme.deepBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('👥 المستخدمون'),
                  Row(
                    children: [
                      Expanded(child: _mini('الإجمالي', '${_i('totalUsers')}', Icons.people)),
                      const SizedBox(width: 12),
                      Expanded(child: _mini('الوسطاء', '${_i('brokers')}', Icons.handshake)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _bar('نشط', _i('activeUsers'), _i('totalUsers'), Colors.green),
                  _bar('محظور', _i('bannedUsers'), _i('totalUsers'), AppTheme.errorRed),

                  const SizedBox(height: 24),
                  _section('🏠 العروض'),
                  Row(
                    children: [
                      Expanded(child: _mini('الإجمالي', '${_i('totalOffers')}', Icons.home_work)),
                      const SizedBox(width: 12),
                      Expanded(child: _mini('معلّق', '${_i('pendingOffers')}', Icons.pending_actions)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _bar('منشور', _i('publishedOffers'), _i('totalOffers'), Colors.green),
                  _bar('معلّق', _i('pendingOffers'), _i('totalOffers'), Colors.orange),

                  const SizedBox(height: 24),
                  _section('📅 المواعيد'),
                  _bar('مكتمل', _i('completedAppointments'), _i('totalAppointments'),
                      AppTheme.primaryGold),

                  const SizedBox(height: 24),
                  _section('🤝 الصفقات والإيرادات'),
                  _bar('مكتملة', _i('completedDeals'), _i('totalDeals'), Colors.green),
                  const SizedBox(height: 12),
                  _bigMetric('إجمالي عمولات المكتب',
                      '${_d('totalCommission').toStringAsFixed(0)} \$', gold: true),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t,
            style: const TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      );

  Widget _mini(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 26),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _bar(String label, int value, int total, Color color) {
    final pct = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 13)),
              Text('$value (${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppTheme.surfaceBlack,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigMetric(String label, String value, {bool gold = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: gold ? AppTheme.primaryGold.withValues(alpha: 0.5) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: gold ? AppTheme.primaryGold : AppTheme.textWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
