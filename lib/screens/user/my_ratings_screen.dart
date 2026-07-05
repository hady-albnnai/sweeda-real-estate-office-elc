import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';

/// ⭐ شاشة "تقييماتي المستلمة"
///
/// تعرض كل التقييمات التي وردت للمستخدم الحالي مرتبة من الأحدث للأقدم،
/// مع متوسط النجوم وإحصائيات مختصرة.
///
/// مرجع: docs/LOGIC_SPEC.md §3.3
class MyRatingsScreen extends StatefulWidget {
  const MyRatingsScreen({super.key});

  @override
  State<MyRatingsScreen> createState() => _MyRatingsScreenState();
}

class _MyRatingsScreenState extends State<MyRatingsScreen> {
  List<Map<String, dynamic>> _ratings = [];
  bool _loading = true;
  double _avg = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await SupabaseService()
          .client
          .from('ratings')
          .select()
          .eq('target_uid', user.uid)
          .order('ts_crt', ascending: false);
      final list =
          (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
      double sum = 0;
      for (final r in list) {
        sum += ((r['stars'] as num?) ?? 0).toDouble();
      }
      if (!mounted) return;
      setState(() {
        _ratings = list;
        _avg = list.isEmpty ? 0 : sum / list.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppTheme.showSnackBar(context,
        SnackBar(content: Text('❌ فشل تحميل التقييمات: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('تقييماتي المستلمة'),
        backgroundColor: AppTheme.scaffoldBackground,
        foregroundColor: AppTheme.primaryGold,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : _ratings.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: AppTheme.primaryGold,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 12),
                      ..._ratings.map(_ratingTile),
                    ],
                  ),
                ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline,
              color: AppTheme.textGrey.withOpacity(0.4), size: 80),
          const SizedBox(height: 12),
          Text('لم تستلم أي تقييم بعد',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
          const SizedBox(height: 6),
          Text('أكمل صفقات وقدّم خدمة ممتازة لتحصل على تقييمات',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final count = _ratings.length;
    final fiveStars = _ratings.where((r) => (r['stars'] ?? 0) == 5).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // متوسط النجوم
          Column(
            children: [
              Text(_avg.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 36,
                      fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final full = i < _avg.floor();
                  final half = !full && (i < _avg);
                  return Icon(
                    half
                        ? Icons.star_half
                        : (full ? Icons.star : Icons.star_border),
                    color: Colors.black87,
                    size: 18,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(width: 18),
          // إحصائيات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count تقييم إجمالي',
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('منها $fiveStars بـ 5 نجوم ⭐',
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                    fiveStars > 0
                        ? '🎁 حصلت على ${fiveStars * 200} نقطة مكافأة'
                        : 'احصل على 200 نقطة عند كل تقييم 5 نجوم',
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingTile(Map<String, dynamic> r) {
    final stars = (r['stars'] ?? 0) as int;
    final comment = (r['comment'] ?? '') as String;
    final ts = r['ts_crt'] as String?;
    DateTime? date;
    if (ts != null) {
      try {
        date = DateTime.parse(ts).toLocal();
      } catch (_) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // النجوم
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < stars ? Icons.star : Icons.star_border,
                    color: AppTheme.primaryGold,
                    size: 18,
                  );
                }),
              ),
              const Spacer(),
              if (date != null)
                Text(
                  '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      color: AppTheme.textGrey, fontSize: 11),
                ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"$comment"',
              style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.5),
            ),
          ],
          // 🏢 لا نُظهر اسم المُقيِّم لحماية الخصوصية (هوية المكتب)
          const SizedBox(height: 6),
          Text('— تقييم من عميل عبر المكتب',
              style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
