import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../providers/auth_provider.dart';

/// 🕵️ Phase 9: شاشة كشف الاحتيال (حسابات متعددة من نفس الجهاز).
///
/// تعرض المخرج من RPC `admin_fraud_suspects` — كل صف = device_id + قائمة
/// المستخدمين الذين سُجّلوا منه. الأدمن يفحصهم ويُحدد إن كانوا أشخاصاً مختلفين
/// أم مزرعة احتيال.
///
/// مرجع: docs/LOGIC_SPEC.md §5
class FraudSuspectsScreen extends StatefulWidget {
  const FraudSuspectsScreen({super.key});

  @override
  State<FraudSuspectsScreen> createState() => _FraudSuspectsScreenState();
}

class _FraudSuspectsScreenState extends State<FraudSuspectsScreen> {
  List<Map<String, dynamic>> _suspects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final adminId = auth.userModel?.uid;
      
      final res =
          await SupabaseService().client.rpc('admin_fraud_suspects', params: {'p_admin_uid': adminId});
      final list =
          (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _suspects = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('كشف الاحتيال'),
        backgroundColor: AppTheme.deepBlack,
        foregroundColor: AppTheme.primaryGold,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '❌ تعذّر التحميل\n${_error!}',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: AppTheme.errorRed),
                  ),
                ))
              : _suspects.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      color: AppTheme.primaryGold,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _suspects.length,
                        itemBuilder: (_, i) => _suspectCard(_suspects[i]),
                      ),
                    ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user, color: Colors.green, size: 80),
          SizedBox(height: 12),
          Text('لا توجد حسابات مشبوهة',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
          SizedBox(height: 6),
          Text('كل المستخدمين على أجهزة فريدة 🎉',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _suspectCard(Map<String, dynamic> s) {
    final deviceId = (s['device_id'] ?? '') as String;
    final count = (s['account_count'] ?? 0) as int;
    final names = ((s['names'] ?? []) as List).cast<String>();
    final ids = ((s['user_ids'] ?? []) as List).cast<String>();

    Color tone;
    if (count >= 5) {
      tone = Colors.red;
    } else if (count >= 3) {
      tone = Colors.orange;
    } else {
      tone = AppTheme.primaryGold;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber, color: tone, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$count حسابات من نفس الجهاز',
                style: TextStyle(
                    color: tone,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Device: ${deviceId.length > 16 ? '${deviceId.substring(0, 16)}…' : deviceId}',
            style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 11,
                fontFamily: 'monospace'),
          ),
          const Divider(color: AppTheme.textGrey, height: 16),
          ...List.generate(names.length, (i) {
            final name = names[i].isNotEmpty ? names[i] : 'بدون اسم';
            final uid = ids[i];
            return InkWell(
              onTap: () => context.push('/admin/user/$uid'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.person,
                      color: AppTheme.primaryGold, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            color: AppTheme.textWhite, fontSize: 13)),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: AppTheme.textGrey, size: 12),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}
