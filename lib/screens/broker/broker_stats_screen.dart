import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/broker_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

/// 📈 إحصائيات الوسيط التفصيلية — أرقام + رسوم بسيطة (بدون مكتبات خارجية)
class BrokerStatsScreen extends StatefulWidget {
  const BrokerStatsScreen({super.key});

  @override
  State<BrokerStatsScreen> createState() => _BrokerStatsScreenState();
}

class _BrokerStatsScreenState extends State<BrokerStatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final id = context.read<AuthProvider>().userModel?.uid ?? '';
    if (id.isNotEmpty) context.read<BrokerProvider>().fetchBrokerStats(id);
  }

  @override
  Widget build(BuildContext context) {
    final broker = context.watch<BrokerProvider>();
    final s = broker.stats;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('الإحصائيات'),
        backgroundColor: AppTheme.scaffoldBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: broker.isLoading && s.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: () async => _load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('📊 نظرة عامة'),
                  Row(
                    children: [
                      Expanded(
                          child: _miniStat('العروض', '${s['totalOffers'] ?? 0}',
                              Icons.home_work)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _miniStat('المشاهدات',
                              '${s['totalViews'] ?? 0}', Icons.visibility)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _miniStat('المفضلة', '${s['totalFavs'] ?? 0}',
                              Icons.favorite)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _miniStat('المواعيد',
                              '${s['totalAppointments'] ?? 0}',
                              Icons.calendar_today)),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _section('🏠 حالة العروض'),
                  _bar('منشورة', _toInt(s['publishedOffers']),
                      _toInt(s['totalOffers']), Colors.green),
                  _bar(
                      'غير منشورة',
                      _toInt(s['totalOffers']) - _toInt(s['publishedOffers']),
                      _toInt(s['totalOffers']),
                      Colors.orange),

                  const SizedBox(height: 24),
                  _section('📅 المواعيد'),
                  _bar('مكتملة', _toInt(s['completedAppointments']),
                      _toInt(s['totalAppointments']), AppTheme.primaryGold),
                  _bar(
                      'غير مكتملة',
                      _toInt(s['totalAppointments']) -
                          _toInt(s['completedAppointments']),
                      _toInt(s['totalAppointments']),
                      AppTheme.textGrey),

                  const SizedBox(height: 24),
                  _section('🤝 الصفقات والعمولات'),
                  _bar('صفقات مكتملة', _toInt(s['completedDeals']),
                      _toInt(s['totalDeals']), Colors.green),
                  const SizedBox(height: 12),
                  _bigMetric('إجمالي قيمة الصفقات',
                      '${_toDouble(s['totalDealsValue']).toStringAsFixed(0)} \$'),
                  const SizedBox(height: 12),
                  _bigMetric('إجمالي العمولات المحققة',
                      '${_toDouble(s['totalCommission']).toStringAsFixed(0)} \$',
                      gold: true),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  int _toInt(dynamic v) => ((v ?? 0) as num).toInt();
  double _toDouble(dynamic v) => ((v ?? 0) as num).toDouble();

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: const TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      );

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 26),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  /// شريط نسبة بسيط مرسوم بـ widgets أصلية
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
                  style: TextStyle(
                      color: AppTheme.textWhite, fontSize: 13)),
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
            color: (gold ? AppTheme.primaryGold : Colors.white12)
                .withOpacity(gold ? 0.5 : 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
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
